import { useEffect } from 'react';
import { usePageTracking } from '../hooks/usePageTracking';

interface PageTrackerProps {
  pagePath: string;
  pageTitle: string;
  children: React.ReactNode;
}

export default function PageTracker({ pagePath, pageTitle, children }: PageTrackerProps) {
  usePageTracking(pagePath, pageTitle);
  return <>{children}</>;
}
