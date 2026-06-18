import { useEffect } from 'react';

/**
 * Custom hook to set document title dynamically.
 * Automatically appends " | GateWA" suffix.
 */
export function useDocumentTitle(title: string) {
  useEffect(() => {
    const previousTitle = document.title;
    document.title = `${title} | GateWA`;

    return () => {
      document.title = previousTitle;
    };
  }, [title]);
}
