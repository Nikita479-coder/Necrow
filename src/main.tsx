import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import { priceUpdateService } from './services/priceUpdateService';
import { priceSyncService } from './services/priceSyncService';

priceUpdateService.start();
priceSyncService.start();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
);
