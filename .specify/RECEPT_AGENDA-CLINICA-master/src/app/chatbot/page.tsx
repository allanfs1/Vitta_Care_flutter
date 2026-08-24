
'use client';

import * as React from 'react';
import { Bot, Send, User, Paperclip, X } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import Image from 'next/image';

import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { PageHeader } from '@/components/page-header';
import { cn } from '@/lib/utils';
import { useAuth } from '@/contexts/auth-context';
import type { ChatMessage, FileInput } from '@/lib/types';
import { chat } from '@/ai/flows/chat-flow';
import { Card, CardContent } from '@/components/ui/card';
import { useToast } from '@/hooks/use-toast';


export default function ChatbotPage() {
  const { user } = useAuth();
  const [messages, setMessages] = React.useState<ChatMessage[]>([]);
  const [input, setInput] = React.useState('');
  const [files, setFiles] = React.useState<FileInput[]>([]);
  const [isLoading, setIsLoading] = React.useState(false);
  const messagesEndRef = React.useRef<HTMLDivElement>(null);
  const fileInputRef = React.useRef<HTMLInputElement>(null);
  const { toast } = useToast();
  

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  React.useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setInput(e.target.value);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      const selectedFiles = e.target.files;
      if (!selectedFiles) return;

      const newFiles: Promise<FileInput>[] = Array.from(selectedFiles)
          // Allow images and PDFs
          .filter(file => file.type.startsWith('image/') || file.type === 'application/pdf') 
          .map(file => {
              return new Promise((resolve, reject) => {
                  const reader = new FileReader();
                  reader.onload = (event) => {
                      if(event.target?.result) {
                        const dataUrl = event.target.result as string;
                        resolve({
                            // Get only base64 part
                            data: dataUrl.split(',')[1], 
                            mimeType: file.type,
                            name: file.name,
                            // Create a preview URL for images, but not for PDFs
                            previewUrl: file.type.startsWith('image/') ? dataUrl : undefined
                        });
                      } else {
                        reject(new Error("Failed to read file"));
                      }
                  };
                  reader.onerror = reject;
                  // Read as Data URL to get base64 and for image preview
                  reader.readAsDataURL(file); 
              });
          });

      Promise.all(newFiles)
        .then(processedFiles => {
            setFiles(prev => [...prev, ...processedFiles].slice(0, 5)); // Limit to 5 files
        })
        .catch(error => {
            console.error("Error processing files:", error);
            toast({
                variant: 'destructive',
                title: 'Erro ao carregar arquivo',
                description: 'Não foi possível processar o arquivo selecionado.',
            });
        });
      
      // Reset file input so the same file can be selected again
      e.target.value = '';
  };
  
  const removeFile = (index: number) => {
      setFiles(prev => prev.filter((_, i) => i !== index));
  };
  
  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!input.trim() && files.length === 0) return;

    const userMessage: ChatMessage = {
      id: String(Date.now()),
      role: 'user',
      content: input,
      files: files,
    };
    
    setMessages(prev => [...prev, userMessage]);
    setIsLoading(true);
    setInput('');
    setFiles([]);
    
    try {
        const response = await chat({ prompt: input, files: userMessage.files });

        const aiMessage: ChatMessage = {
            id: String(Date.now() + 1),
            role: 'assistant',
            content: response.response,
        };
        setMessages(prev => [...prev, aiMessage]);

    } catch (error) {
         const errorMessage: ChatMessage = {
            id: String(Date.now() + 1),
            role: 'assistant',
            content: 'Desculpe, ocorreu um erro ao processar sua solicitação. Verifique se a chave de API está configurada corretamente e tente novamente.',
        };
        setMessages(prev => [...prev, errorMessage]);
        console.error("Chat error:", error);
    } finally {
        setIsLoading(false);
    }
  };


  const getInitials = (name: string | null | undefined) => {
    if (!name) return 'U';
    return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
  };

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)]">
        <div className="p-4 sm:p-6 lg:p-8 border-b">
            <PageHeader 
                title="Assistente de IA"
                description="Converse para gerar relatórios e análises, anexe imagens ou PDFs para extração de texto."
            />
        </div>
      <div className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 space-y-6">
        {messages.map((message, index) => (
          <div
            key={index}
            className={cn(
              'flex items-start gap-4',
              message.role === 'user' ? 'justify-end' : 'justify-start'
            )}
          >
            {message.role === 'assistant' && (
              <Avatar className="h-10 w-10 border">
                <AvatarFallback>
                  <Bot />
                </AvatarFallback>
              </Avatar>
            )}
            <div
              className={cn(
                'max-w-2xl rounded-lg p-1 space-y-2',
                message.role === 'user'
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-transparent'
              )}
            >
                {message.files && message.files.length > 0 && (
                     <div className="grid grid-cols-2 gap-2 p-2 bg-primary/80 rounded-md">
                        {message.files.map((file, fileIndex) => (
                             <div key={fileIndex} className="relative">
                                {file.previewUrl ? (
                                    <Image
                                        src={file.previewUrl}
                                        alt={file.name || `attachment ${fileIndex + 1}`}
                                        width={150}
                                        height={150}
                                        className="rounded-md object-cover"
                                    />
                                ) : (
                                    <div className="w-[150px] h-[150px] bg-primary/60 text-primary-foreground flex flex-col items-center justify-center p-2 rounded-md">
                                        <Paperclip className="h-8 w-8 mb-2" />
                                        <p className="text-xs text-center break-all">{file.name}</p>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                )}
                {message.content && (
                     <Card className={cn(
                        "bg-transparent border-none shadow-none text-sm",
                        message.role === 'user' ? "p-3" : "p-0"
                    )}>
                      <CardContent className={cn(
                          "p-0",
                          message.role === 'user' ? "" : "prose prose-sm dark:prose-invert max-w-full"
                        )}>
                         <ReactMarkdown>{message.content}</ReactMarkdown>
                      </CardContent>
                  </Card>
                )}
            </div>
            {message.role === 'user' && (
              <Avatar className="h-10 w-10 border">
                <AvatarImage src={user?.photoURL || ''} alt={user?.displayName || ''} />
                <AvatarFallback>{getInitials(user?.displayName)}</AvatarFallback>
              </Avatar>
            )}
          </div>
        ))}
         {isLoading && (
            <div className="flex items-start gap-4 justify-start">
                 <Avatar className="h-10 w-10 border">
                    <AvatarFallback>
                        <Bot />
                    </AvatarFallback>
                 </Avatar>
                <div className="max-w-lg rounded-lg p-3 bg-muted flex items-center space-x-2">
                    <span className="h-2 w-2 bg-primary rounded-full animate-bounce [animation-delay:-0.3s]"></span>
                    <span className="h-2 w-2 bg-primary rounded-full animate-bounce [animation-delay:-0.15s]"></span>
                    <span className="h-2 w-2 bg-primary rounded-full animate-bounce"></span>
                </div>
            </div>
        )}
        <div ref={messagesEndRef} />
      </div>
      
      <div className="border-t p-4 sm:p-6 lg:p-8 bg-background">
        {files.length > 0 && (
            <div className="mb-4 grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2">
                {files.map((file, index) => (
                    <div key={index} className="relative group">
                         {file.previewUrl ? (
                            <Image
                                src={file.previewUrl}
                                alt={file.name || 'preview'}
                                width={100}
                                height={100}
                                className="w-full h-24 object-cover rounded-md"
                            />
                         ) : (
                             <div className="w-full h-24 bg-muted text-muted-foreground flex flex-col items-center justify-center p-2 rounded-md">
                                <Paperclip className="h-6 w-6 mb-1" />
                             </div>
                         )}
                        <button
                            onClick={() => removeFile(index)}
                            className="absolute top-1 right-1 bg-gray-900/50 text-white rounded-full p-1 group-hover:opacity-100 opacity-0 transition-opacity"
                        >
                            <X className="h-3 w-3" />
                        </button>
                        <div className="absolute bottom-0 left-0 right-0 bg-gray-900/50 text-white text-xs p-1 truncate rounded-b-md">
                            {file.name}
                        </div>
                    </div>
                ))}
            </div>
        )}
        <form onSubmit={handleSubmit} className="flex items-center gap-2 md:gap-4">
          <input 
            type="file" 
            ref={fileInputRef} 
            onChange={handleFileChange}
            className="hidden"
            accept="image/*,application/pdf"
            multiple 
          />
           <Button 
            type="button" 
            variant="outline" 
            size="icon" 
            onClick={() => fileInputRef.current?.click()}
            disabled={isLoading}
          >
             <Paperclip className="h-4 w-4" />
             <span className="sr-only">Anexar</span>
           </Button>
          <Input
            value={input}
            onChange={handleInputChange}
            placeholder="Digite sua mensagem ou anexe arquivos..."
            className="flex-1"
            disabled={isLoading}
          />
          <Button type="submit" size="icon" disabled={isLoading || (!input.trim() && files.length === 0)}>
            <Send className="h-4 w-4" />
            <span className="sr-only">Enviar</span>
          </Button>
        </form>
      </div>
    </div>
  );
}
