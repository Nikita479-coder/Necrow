import { useEffect, useState } from 'react';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import Navbar from '../components/Navbar';
import {
  ArrowLeft,
  Shield,
  CheckCircle
} from 'lucide-react';

interface LegalDocument {
  id: string;
  version: string;
  title: string;
  content: string;
  document_type: string;
  effective_date: string;
  is_active: boolean;
}

export default function PrivacyPolicy() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const [document, setDocument] = useState<LegalDocument | null>(null);
  const [loading, setLoading] = useState(true);
  const [accepted, setAccepted] = useState(false);
  const [accepting, setAccepting] = useState(false);

  useEffect(() => {
    loadPrivacyPolicy();
  }, [user]);

  const loadPrivacyPolicy = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('terms_and_conditions')
        .select('*')
        .eq('document_type', 'privacy_policy')
        .eq('is_active', true)
        .single();

      if (error) throw error;
      setDocument(data);

      if (user && data) {
        const { data: acceptanceData } = await supabase
          .from('user_terms_acceptance')
          .select('terms_id')
          .eq('user_id', user.id)
          .eq('terms_id', data.id)
          .maybeSingle();

        setAccepted(!!acceptanceData);
      }
    } catch (error) {
      console.error('Error loading privacy policy:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAccept = async () => {
    if (!user || !document) return;

    setAccepting(true);
    try {
      const { error } = await supabase
        .from('user_terms_acceptance')
        .insert({
          user_id: user.id,
          terms_id: document.id,
          version: document.version,
          user_agent: navigator.userAgent
        });

      if (error) throw error;
      setAccepted(true);
    } catch (error: any) {
      console.error('Error accepting privacy policy:', error);
    } finally {
      setAccepting(false);
    }
  };

  const formatContent = (content: string) => {
    const lines = content.split('\n');
    const formatted: JSX.Element[] = [];
    let listItems: string[] = [];
    let inList = false;
    let tableRows: string[][] = [];
    let inTable = false;
    let tableHeaders: string[] = [];

    const processBoldText = (text: string) => {
      const parts = text.split(/(\*\*.*?\*\*)/g);
      return parts.map((part, i) => {
        if (part.startsWith('**') && part.endsWith('**')) {
          return <strong key={i} className="font-bold text-white">{part.slice(2, -2)}</strong>;
        }
        return part;
      });
    };

    const flushList = (index: number) => {
      if (listItems.length > 0) {
        formatted.push(
          <ul key={`list-${index}`} className="list-disc list-inside space-y-2 mb-6 text-slate-300 ml-4">
            {listItems.map((item, i) => (
              <li key={i}>{processBoldText(item)}</li>
            ))}
          </ul>
        );
        listItems = [];
        inList = false;
      }
    };

    const flushTable = (index: number) => {
      if (tableRows.length > 0) {
        formatted.push(
          <div key={`table-${index}`} className="overflow-x-auto mb-6">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-600">
                  {tableHeaders.map((h, i) => (
                    <th key={i} className="text-left py-2 px-3 text-slate-300 font-semibold">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {tableRows.map((row, ri) => (
                  <tr key={ri} className="border-b border-slate-700">
                    {row.map((cell, ci) => (
                      <td key={ci} className="py-2 px-3 text-slate-400">{cell}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        );
        tableRows = [];
        tableHeaders = [];
        inTable = false;
      }
    };

    lines.forEach((line, index) => {
      if (line.startsWith('|') && line.endsWith('|')) {
        const cells = line.split('|').filter(c => c.trim()).map(c => c.trim());
        if (cells.every(c => c.match(/^-+$/))) {
          return;
        }
        if (!inTable) {
          flushList(index);
          tableHeaders = cells;
          inTable = true;
        } else {
          tableRows.push(cells);
        }
        return;
      } else if (inTable) {
        flushTable(index);
      }

      if (line.startsWith('# ')) {
        flushList(index);
        formatted.push(
          <h1 key={index} className="text-3xl font-bold text-white mb-6 mt-8 first:mt-0">
            {line.substring(2)}
          </h1>
        );
      } else if (line.startsWith('## ')) {
        flushList(index);
        formatted.push(
          <h2 key={index} className="text-2xl font-bold text-white mb-4 mt-8">
            {line.substring(3)}
          </h2>
        );
      } else if (line.startsWith('### ')) {
        flushList(index);
        formatted.push(
          <h3 key={index} className="text-xl font-semibold text-[#f0b90b] mb-3 mt-6">
            {line.substring(4)}
          </h3>
        );
      } else if (line.startsWith('- ')) {
        inList = true;
        listItems.push(line.substring(2));
      } else if (line.trim() === '---') {
        flushList(index);
        formatted.push(
          <hr key={index} className="border-slate-600 my-6" />
        );
      } else if (line.trim() === '') {
        flushList(index);
      } else if (line.trim() !== '') {
        flushList(index);
        formatted.push(
          <p key={index} className="text-slate-300 mb-4 leading-relaxed">
            {processBoldText(line)}
          </p>
        );
      }
    });

    flushList(lines.length);
    flushTable(lines.length);

    return formatted;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-slate-400">Loading privacy policy...</div>
        </div>
      </div>
    );
  }

  if (!document) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-slate-400">Privacy policy not found.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />
      <div className="max-w-4xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('legal')}
          className="flex items-center gap-2 text-slate-400 hover:text-white mb-6 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Legal Hub
        </button>

        <div className="bg-[#181a20] border border-gray-800 rounded-xl overflow-hidden">
          <div className="bg-gradient-to-r from-[#1a1d24] to-[#181a20] p-6 border-b border-gray-800">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-[#f0b90b]/10 rounded-lg text-[#f0b90b]">
                  <Shield className="w-5 h-5" />
                </div>
                <div>
                  <h1 className="text-2xl font-bold text-white">{document.title}</h1>
                  <div className="flex items-center gap-4 mt-2 text-sm text-slate-400">
                    <span>Version {document.version}</span>
                    <span>Effective {new Date(document.effective_date).toLocaleDateString()}</span>
                  </div>
                </div>
              </div>
              {accepted && (
                <div className="flex items-center gap-2 text-green-400 bg-green-500/10 px-3 py-1.5 rounded-lg">
                  <CheckCircle className="w-4 h-4" />
                  <span className="text-sm">Accepted</span>
                </div>
              )}
            </div>
          </div>

          <div className="p-8">
            <div className="prose prose-invert max-w-none">
              {formatContent(document.content)}
            </div>

            <div className="mt-8 pt-6 border-t border-gray-800">
              <p className="text-sm text-slate-500 mb-4">
                Last updated: {new Date(document.effective_date).toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric'
                })}
              </p>

              <div className="flex items-center gap-4">
                {accepted ? (
                  <div className="flex items-center gap-2 text-green-400">
                    <CheckCircle className="w-5 h-5" />
                    <span>You have accepted this document</span>
                  </div>
                ) : user ? (
                  <button
                    onClick={handleAccept}
                    disabled={accepting}
                    className="px-6 py-2 bg-[#f0b90b] text-black font-semibold rounded-lg hover:bg-[#d9a506] transition-colors disabled:opacity-50"
                  >
                    {accepting ? 'Recording...' : 'I Accept This Policy'}
                  </button>
                ) : (
                  <p className="text-slate-400">
                    Please <button onClick={() => navigateTo('signin')} className="text-[#f0b90b] hover:underline">sign in</button> to accept this policy.
                  </p>
                )}
                <button
                  onClick={() => navigateTo('legal')}
                  className="px-6 py-2 bg-gray-700 text-white rounded-lg hover:bg-gray-600 transition-colors"
                >
                  Back to Legal Hub
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
