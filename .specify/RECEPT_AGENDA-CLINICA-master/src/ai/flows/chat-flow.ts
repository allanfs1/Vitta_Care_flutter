
'use server';
/**
 * @fileOverview A flow for handling chat interactions via a direct API call.
 * It now uses Azure Cognitive Services to extract text from images (sync) and PDFs (async).
 */
import { z } from 'zod';
import type { FileInput } from '@/lib/types';

// Define the schema for the main flow input
const ChatInputSchema = z.object({
  prompt: z.string().describe("The user's text prompt."),
  files: z.array(z.any()).optional().describe("An array of files to be included in the chat."),
});
export type ChatInput = z.infer<typeof ChatInputSchema>;

// Define the schema for the flow's output
const ChatOutputSchema = z.object({
  response: z.string().describe('The generated response from the AI.'),
});
export type ChatOutput = z.infer<typeof ChatOutputSchema>;

// Helper function to sleep
const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

const AZURE_API_KEY = process.env.AZURE_VISION_KEY;
const AZURE_ENDPOINT = process.env.AZURE_VISION_ENDPOINT;

/**
 * Extracts text from an image using Azure's synchronous OCR API.
 * @param file The image file to analyze.
 * @returns The extracted text as a string.
 */
async function extractTextFromImage(file: FileInput): Promise<string> {
    if (!AZURE_ENDPOINT || !AZURE_API_KEY) {
        throw new Error('Azure Vision credentials are not configured.');
    }
    const ocrEndpoint = `${AZURE_ENDPOINT}/vision/v3.2/ocr?language=pt&detectOrientation=true`;
    const imageBuffer = Buffer.from(file.data, 'base64');
    
    try {
        const response = await fetch(ocrEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': file.mimeType,
                'Ocp-Apim-Subscription-Key': AZURE_API_KEY,
            },
            body: imageBuffer,
        });

        if (!response.ok) {
            const errorBody = await response.text();
            console.error('Azure OCR API Error:', errorBody);
            throw new Error(`Azure OCR API returned an error: ${response.status}`);
        }

        const result = await response.json();
        let extractedText = "";
        if (result && result.regions) {
            result.regions.forEach((region: any) => {
                region.lines.forEach((line: any) => {
                    const lineText = line.words.map((word: any) => word.text).join(" ");
                    extractedText += lineText + "\n";
                });
            });
        }
        return extractedText;

    } catch (error) {
        console.error('Error during Azure image text extraction:', error);
        return `[Erro ao extrair texto da imagem ${file.name || 'anexo'}]`;
    }
}


/**
 * Extracts text from a PDF using Azure's asynchronous Read API.
 * @param file The PDF file to analyze.
 * @returns The extracted text as a string.
 */
async function extractTextFromPdf(file: FileInput): Promise<string> {
    if (!AZURE_ENDPOINT || !AZURE_API_KEY) {
        throw new Error('Azure Vision credentials are not configured.');
    }
    const readEndpoint = `${AZURE_ENDPOINT}/vision/v3.2/read/analyze?language=pt`;
    const fileBuffer = Buffer.from(file.data, 'base64');

    try {
        // Step 1: Send the file to Azure to start the analysis
        const postResponse = await fetch(readEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/pdf',
                'Ocp-Apim-Subscription-Key': AZURE_API_KEY,
            },
            body: fileBuffer,
        });

        if (!postResponse.ok || !postResponse.headers.has('operation-location')) {
            const errorBody = await postResponse.text();
            console.error('Azure Read API Error (POST):', errorBody);
            throw new Error(`Azure Read API returned an error: ${postResponse.status}`);
        }

        const operationLocation = postResponse.headers.get('operation-location')!;
        
        // Step 2: Poll the operation location URL to get the results
        let analysisResult;
        let status = 'notStarted';
        
        const maxRetries = 15;
        let retries = 0;
        while ((status === 'running' || status === 'notStarted') && retries < maxRetries) {
            await sleep(2000); // Wait for 2 seconds before polling
            const getResponse = await fetch(operationLocation, {
                headers: { 'Ocp-Apim-Subscription-Key': AZURE_API_KEY },
            });
            if (!getResponse.ok) {
                throw new Error(`Azure API returned an error on GET: ${getResponse.status}`);
            }
            analysisResult = await getResponse.json();
            status = analysisResult.status;
            retries++;
        }

        if (status === 'succeeded') {
            let extractedText = '';
            for (const readResult of analysisResult.analyzeResult.readResults) {
                for (const line of readResult.lines) {
                    extractedText += line.text + '\n';
                }
            }
            return extractedText;
        } else {
             throw new Error(`Azure text extraction failed or timed out with status: ${status}`);
        }

    } catch (error) {
        console.error('Error during Azure PDF text extraction:', error);
        return `[Erro ao extrair texto do PDF ${file.name || 'anexo'}]`;
    }
}


/**
 * Sends a prompt to a custom AI endpoint. If files are provided,
 * they are first analyzed by the appropriate Azure Vision API to extract text, 
 * and the extracted text is added to the prompt.
 * @param input The user's prompt and optional files.
 * @returns The AI's response.
 */
export async function chat(input: ChatInput): Promise<ChatOutput> {
  const { prompt, files } = input;
  
  let augmentedPrompt = prompt;

  // Step 1: If there are files, use the correct  Azure API to extract text.
  if (files && files.length > 0) {
    const fileDescriptions: string[] = [];

    for (const file of files) {
        let extractedText = '';
        if (file.mimeType.startsWith('image/')) {
            extractedText = await extractTextFromImage(file);
        } else if (file.mimeType === 'application/pdf') {
            extractedText = await extractTextFromPdf(file);
        }
        
        if (extractedText) {
             fileDescriptions.push(`Conteúdo extraído do arquivo (${file.name || 'anexo'}):\n---\n${extractedText}\n---`);
        }
    }
    
    if (fileDescriptions.length > 0) {
      augmentedPrompt = `${prompt}\n\nContexto adicional dos arquivos fornecidos:\n${fileDescriptions.join('\n')}`;
    }
  }

  // Step 2: Call the DeepSeek API with the (potentially augmented) prompt.
  const apiKey = process.env.DEEPSEEK_API_KEY; 
  const endpoint = process.env.DEEPSEEK_ENDPOINT;

  if (!apiKey || !endpoint) {
    throw new Error('DeepSeek API credentials are not configured.');
  }

  const messages: any[] = [
    {
      role: 'user',
      content: `Você é um assistente de IA especialista em análise de dados e criação de relatórios para uma clínica médica. Sua tarefa é analisar a solicitação do usuário e gerar uma resposta clara e concisa. Se conteúdo de arquivos for fornecido, analise-o como parte do contexto. Solicitação: ${augmentedPrompt}`
    },
  ];

  const body = {
    model: 'deepseek-chat', 
    messages,
    max_tokens: 4096,
  };

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('API Error Response:', errorBody);
      throw new Error(`A API retornou um erro: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();
    const textResponse = result.choices?.[0]?.message?.content || 'Não foi possível obter uma resposta da IA.';
    
    return {
      response: textResponse,
    };
  } catch (error) {
    console.error('Erro ao chamar a API de chat:', error);
    throw new Error('Falha ao se comunicar com o serviço de IA.');
  }
}
