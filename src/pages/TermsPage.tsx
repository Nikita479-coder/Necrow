import { useEffect, useState } from 'react';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import Navbar from '../components/Navbar';
import { ArrowLeft, FileText, CheckCircle } from 'lucide-react';

interface TermsData {
  id: string;
  version: string;
  title: string;
  content: string;
  effective_date: string;
  is_active: boolean;
}

interface TermsAcceptance {
  id: string;
  accepted_at: string;
  version: string;
}

export default function TermsPage() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const [terms, setTerms] = useState<TermsData | null>(null);
  const [acceptance, setAcceptance] = useState<TermsAcceptance | null>(null);
  const [loading, setLoading] = useState(true);
  const [accepting, setAccepting] = useState(false);

  useEffect(() => {
    loadTerms();
  }, [user]);

  const loadTerms = async () => {
    setLoading(true);
    try {
      // Load active terms
      const { data: termsData, error: termsError } = await supabase
        .from('terms_and_conditions')
        .select('*')
        .eq('is_active', true)
        .order('effective_date', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (termsError) throw termsError;
      setTerms(termsData);

      // Check if user has accepted these terms
      if (user && termsData) {
        const { data: acceptanceData, error: acceptanceError } = await supabase
          .from('user_terms_acceptance')
          .select('*')
          .eq('user_id', user.id)
          .eq('terms_id', termsData.id)
          .maybeSingle();

        if (!acceptanceError && acceptanceData) {
          setAcceptance(acceptanceData);
        }
      }
    } catch (error) {
      console.error('Error loading terms:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAccept = async () => {
    if (!user || !terms) return;

    setAccepting(true);
    try {
      // Get user's IP and user agent (client-side, for logging purposes)
      const userAgent = navigator.userAgent;

      const { error } = await supabase
        .from('user_terms_acceptance')
        .insert({
          user_id: user.id,
          terms_id: terms.id,
          version: terms.version,
          user_agent: userAgent
        });

      if (error) throw error;

      // Reload to update acceptance status
      await loadTerms();
    } catch (error: any) {
      console.error('Error accepting terms:', error);
      alert('Failed to record acceptance. Please try again.');
    } finally {
      setAccepting(false);
    }
  };

  const formatContent = (content: string) => {
    const lines = content.split('\n');
    const formatted: JSX.Element[] = [];
    let listItems: string[] = [];
    let inList = false;

    const processBoldText = (text: string) => {
      const parts = text.split(/(\*\*.*?\*\*)/g);
      return parts.map((part, i) => {
        if (part.startsWith('**') && part.endsWith('**')) {
          return <strong key={i} className="font-bold text-white">{part.slice(2, -2)}</strong>;
        }
        return part;
      });
    };

    lines.forEach((line, index) => {
      if (line.startsWith('# ')) {
        if (inList && listItems.length > 0) {
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
        formatted.push(
          <h1 key={index} className="text-3xl font-bold text-white mb-6 mt-8 first:mt-0">
            {line.substring(2)}
          </h1>
        );
      } else if (line.startsWith('## ')) {
        if (inList && listItems.length > 0) {
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
        formatted.push(
          <h2 key={index} className="text-2xl font-bold text-white mb-4 mt-6">
            {line.substring(3)}
          </h2>
        );
      } else if (line.startsWith('### ')) {
        if (inList && listItems.length > 0) {
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
        formatted.push(
          <h3 key={index} className="text-xl font-semibold text-blue-400 mb-3 mt-4">
            {line.substring(4)}
          </h3>
        );
      } else if (line.startsWith('- ')) {
        inList = true;
        listItems.push(line.substring(2));
      } else if (line.trim() === '---') {
        if (inList && listItems.length > 0) {
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
        formatted.push(
          <hr key={index} className="border-slate-600 my-6" />
        );
      } else if (line.trim() === '') {
        if (inList && listItems.length > 0) {
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
      } else if (line.trim() !== '') {
        if (inList && listItems.length > 0) {
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
        formatted.push(
          <p key={index} className="text-slate-300 mb-4 leading-relaxed">
            {processBoldText(line)}
          </p>
        );
      }
    });

    if (inList && listItems.length > 0) {
      formatted.push(
        <ul key="final-list" className="list-disc list-inside space-y-2 mb-6 text-slate-300 ml-4">
          {listItems.map((item, i) => (
            <li key={i}>{processBoldText(item)}</li>
          ))}
        </ul>
      );
    }

    return formatted;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-slate-400">Loading terms and conditions...</div>
        </div>
      </div>
    );
  }

  if (!terms) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-white mb-4">Terms Not Found</h2>
            <button
              onClick={() => navigateTo('home')}
              className="text-blue-400 hover:text-blue-300"
            >
              Return to Home
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800">
      <Navbar />

      <div className="max-w-4xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('home')}
          className="flex items-center gap-2 text-slate-400 hover:text-white mb-6 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>

        <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 overflow-hidden">
          <div className="bg-gradient-to-r from-slate-700 to-slate-600 p-6 border-b border-slate-600">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <FileText className="w-6 h-6 text-blue-400" />
                <div>
                  <h1 className="text-2xl font-bold text-white">{terms.title}</h1>
                  <div className="flex items-center gap-4 mt-2 text-sm text-slate-300">
                    <span>Version {terms.version}</span>
                    <span>•</span>
                    <span>Effective {new Date(terms.effective_date).toLocaleDateString()}</span>
                  </div>
                </div>
              </div>
              {acceptance && (
                <div className="flex items-center gap-2 text-green-400">
                  <CheckCircle className="w-5 h-5" />
                  <span className="text-sm">Accepted</span>
                </div>
              )}
            </div>
          </div>

          <div className="p-8">
            <div className="prose prose-invert max-w-none">
              {formatContent(terms.content)}
            </div>

            <div className="mt-8 pt-6 border-t border-slate-700">
              <p className="text-sm text-slate-400 mb-4">
                Last updated: {new Date(terms.effective_date).toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric'
                })}
              </p>

              {acceptance ? (
                <div className="flex items-center gap-4">
                  <div className="flex items-center gap-2 text-green-400">
                    <CheckCircle className="w-5 h-5" />
                    <span>
                      You accepted these terms on {new Date(acceptance.accepted_at).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </span>
                  </div>
                  <button
                    onClick={() => navigateTo('home')}
                    className="ml-auto px-6 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 transition-colors"
                  >
                    Close
                  </button>
                </div>
              ) : user ? (
                <div className="flex items-center gap-4">
                  <button
                    onClick={handleAccept}
                    disabled={accepting}
                    className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {accepting ? 'Recording Acceptance...' : 'I Accept These Terms'}
                  </button>
                  <button
                    onClick={() => navigateTo('home')}
                    className="px-6 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 transition-colors"
                  >
                    Read Only
                  </button>
                </div>
              ) : (
                <div className="text-slate-400">
                  Please <button onClick={() => navigateTo('signin')} className="text-blue-400 hover:underline">sign in</button> to accept these terms.
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
