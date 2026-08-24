import {genkit} from 'genkit';
import {googleAI} from '@genkit-ai/googleai';

// The Genkit config is used for the vision model to describe images.
export const ai = genkit({
  plugins: [
    googleAI({
        // The API key for Google AI (Gemini) is required for the vision capabilities.
        apiKey: process.env.GEMINI_API_KEY,
    }),
  ],
  logLevel: 'debug',
  enableTracingAndMetrics: true,
});
