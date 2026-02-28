import { useEffect, useState } from 'react';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import Navbar from '../components/Navbar';
import {
  ArrowLeft,
  FileText,
  CheckCircle,
  Shield,
  Lock,
  Scale,
  AlertTriangle,
  CreditCard,
  Users,
  Award,
  Code,
  Ban,
  Gavel,
  Copyright,
  Cookie,
  TrendingUp,
  Copy as CopyIcon,
  Coins,
  Search,
  ChevronRight,
  ExternalLink
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

interface DocumentCategory {
  id: string;
  title: string;
  description: string;
  icon: React.ReactNode;
  documents: string[];
}

const DOCUMENT_CATEGORIES: DocumentCategory[] = [
  {
    id: 'core',
    title: 'Core Legal Documents',
    description: 'Essential terms and policies governing platform use',
    icon: <FileText className="w-5 h-5" />,
    documents: ['terms_of_service', 'privacy_policy', 'cookie_policy', 'acceptable_use']
  },
  {
    id: 'trading',
    title: 'Trading Terms',
    description: 'Rules and terms for trading activities',
    icon: <TrendingUp className="w-5 h-5" />,
    documents: ['trading_rules', 'futures_terms', 'risk_disclosure', 'fee_schedule']
  },
  {
    id: 'services',
    title: 'Service Terms',
    description: 'Terms for specific platform services',
    icon: <Coins className="w-5 h-5" />,
    documents: ['copy_trading_terms', 'staking_terms', 'api_terms']
  },
  {
    id: 'programs',
    title: 'Program Terms',
    description: 'Terms for referral, affiliate, and VIP programs',
    icon: <Award className="w-5 h-5" />,
    documents: ['referral_terms', 'affiliate_terms', 'vip_terms']
  },
  {
    id: 'compliance',
    title: 'Compliance & Legal',
    description: 'Regulatory compliance and legal notices',
    icon: <Scale className="w-5 h-5" />,
    documents: ['aml_kyc_policy', 'dispute_resolution', 'intellectual_property']
  }
];

const DOCUMENT_ICONS: Record<string, React.ReactNode> = {
  terms_of_service: <FileText className="w-5 h-5" />,
  privacy_policy: <Shield className="w-5 h-5" />,
  cookie_policy: <Cookie className="w-5 h-5" />,
  risk_disclosure: <AlertTriangle className="w-5 h-5" />,
  aml_kyc_policy: <Lock className="w-5 h-5" />,
  trading_rules: <Scale className="w-5 h-5" />,
  futures_terms: <TrendingUp className="w-5 h-5" />,
  copy_trading_terms: <CopyIcon className="w-5 h-5" />,
  staking_terms: <Coins className="w-5 h-5" />,
  fee_schedule: <CreditCard className="w-5 h-5" />,
  referral_terms: <Users className="w-5 h-5" />,
  affiliate_terms: <Users className="w-5 h-5" />,
  vip_terms: <Award className="w-5 h-5" />,
  api_terms: <Code className="w-5 h-5" />,
  acceptable_use: <Ban className="w-5 h-5" />,
  dispute_resolution: <Gavel className="w-5 h-5" />,
  intellectual_property: <Copyright className="w-5 h-5" />
};

export default function LegalHub() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const [documents, setDocuments] = useState<LegalDocument[]>([]);
  const [selectedDocument, setSelectedDocument] = useState<LegalDocument | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [acceptances, setAcceptances] = useState<Record<string, boolean>>({});
  const [accepting, setAccepting] = useState(false);

  useEffect(() => {
    loadDocuments();
  }, [user]);

  const loadDocuments = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('terms_and_conditions')
        .select('*')
        .eq('is_active', true)
        .order('title', { ascending: true });

      if (error) throw error;
      setDocuments(data || []);

      if (user && data) {
        const { data: acceptanceData } = await supabase
          .from('user_terms_acceptance')
          .select('terms_id')
          .eq('user_id', user.id);

        if (acceptanceData) {
          const acceptedIds: Record<string, boolean> = {};
          acceptanceData.forEach(a => {
            acceptedIds[a.terms_id] = true;
          });
          setAcceptances(acceptedIds);
        }
      }
    } catch (error) {
      console.error('Error loading documents:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAccept = async (doc: LegalDocument) => {
    if (!user) return;

    setAccepting(true);
    try {
      const { error } = await supabase
        .from('user_terms_acceptance')
        .insert({
          user_id: user.id,
          terms_id: doc.id,
          version: doc.version,
          user_agent: navigator.userAgent
        });

      if (error) throw error;
      setAcceptances(prev => ({ ...prev, [doc.id]: true }));
    } catch (error: any) {
      console.error('Error accepting terms:', error);
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

  const getDocumentByType = (type: string) => {
    return documents.find(d => d.document_type === type);
  };

  const filteredDocuments = documents.filter(doc =>
    doc.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    doc.document_type.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-slate-400">Loading legal documents...</div>
        </div>
      </div>
    );
  }

  if (selectedDocument) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="max-w-4xl mx-auto px-4 py-8">
          <button
            onClick={() => setSelectedDocument(null)}
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
                    {DOCUMENT_ICONS[selectedDocument.document_type] || <FileText className="w-5 h-5" />}
                  </div>
                  <div>
                    <h1 className="text-2xl font-bold text-white">{selectedDocument.title}</h1>
                    <div className="flex items-center gap-4 mt-2 text-sm text-slate-400">
                      <span>Version {selectedDocument.version}</span>
                      <span>Effective {new Date(selectedDocument.effective_date).toLocaleDateString()}</span>
                    </div>
                  </div>
                </div>
                {acceptances[selectedDocument.id] && (
                  <div className="flex items-center gap-2 text-green-400 bg-green-500/10 px-3 py-1.5 rounded-lg">
                    <CheckCircle className="w-4 h-4" />
                    <span className="text-sm">Accepted</span>
                  </div>
                )}
              </div>
            </div>

            <div className="p-8">
              <div className="prose prose-invert max-w-none">
                {formatContent(selectedDocument.content)}
              </div>

              <div className="mt-8 pt-6 border-t border-gray-800">
                <p className="text-sm text-slate-500 mb-4">
                  Last updated: {new Date(selectedDocument.effective_date).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </p>

                <div className="flex items-center gap-4">
                  {acceptances[selectedDocument.id] ? (
                    <div className="flex items-center gap-2 text-green-400">
                      <CheckCircle className="w-5 h-5" />
                      <span>You have accepted this document</span>
                    </div>
                  ) : user ? (
                    <button
                      onClick={() => handleAccept(selectedDocument)}
                      disabled={accepting}
                      className="px-6 py-2 bg-[#f0b90b] text-black font-semibold rounded-lg hover:bg-[#d9a506] transition-colors disabled:opacity-50"
                    >
                      {accepting ? 'Recording...' : 'I Accept These Terms'}
                    </button>
                  ) : (
                    <p className="text-slate-400">
                      Please <button onClick={() => navigateTo('signin')} className="text-[#f0b90b] hover:underline">sign in</button> to accept these terms.
                    </p>
                  )}
                  <button
                    onClick={() => setSelectedDocument(null)}
                    className="px-6 py-2 bg-gray-700 text-white rounded-lg hover:bg-gray-600 transition-colors"
                  >
                    Back
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="max-w-6xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('home')}
          className="flex items-center gap-2 text-slate-400 hover:text-white mb-6 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Home
        </button>

        <div className="mb-8">
          <h1 className="text-4xl font-bold text-white mb-2">Legal Center</h1>
          <p className="text-slate-400">
            Review our terms, policies, and legal documents governing your use of Shark Trades
          </p>
        </div>

        <div className="relative mb-8">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
          <input
            type="text"
            placeholder="Search legal documents..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-[#181a20] border border-gray-800 rounded-xl pl-12 pr-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-[#f0b90b] transition-colors"
          />
        </div>

        {searchQuery ? (
          <div className="space-y-3">
            <h2 className="text-lg font-semibold text-white mb-4">Search Results</h2>
            {filteredDocuments.length === 0 ? (
              <p className="text-slate-400">No documents found matching "{searchQuery}"</p>
            ) : (
              filteredDocuments.map(doc => (
                <button
                  key={doc.id}
                  onClick={() => setSelectedDocument(doc)}
                  className="w-full bg-[#181a20] border border-gray-800 rounded-xl p-4 hover:border-[#f0b90b] transition-all text-left group"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-[#f0b90b]/10 rounded-lg text-[#f0b90b]">
                        {DOCUMENT_ICONS[doc.document_type] || <FileText className="w-5 h-5" />}
                      </div>
                      <div>
                        <div className="font-semibold text-white group-hover:text-[#f0b90b] transition-colors">
                          {doc.title}
                        </div>
                        <div className="text-sm text-slate-500">Version {doc.version}</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {acceptances[doc.id] && (
                        <span className="text-green-400 text-sm flex items-center gap-1">
                          <CheckCircle className="w-4 h-4" />
                          Accepted
                        </span>
                      )}
                      <ChevronRight className="w-5 h-5 text-slate-500 group-hover:text-[#f0b90b] transition-colors" />
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        ) : (
          <div className="space-y-8">
            {DOCUMENT_CATEGORIES.map(category => {
              const categoryDocs = category.documents
                .map(type => getDocumentByType(type))
                .filter(Boolean) as LegalDocument[];

              if (categoryDocs.length === 0) return null;

              return (
                <div key={category.id} className="bg-[#181a20] border border-gray-800 rounded-xl overflow-hidden">
                  <div className="p-5 border-b border-gray-800 bg-gradient-to-r from-[#1a1d24] to-[#181a20]">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-[#f0b90b]/10 rounded-lg text-[#f0b90b]">
                        {category.icon}
                      </div>
                      <div>
                        <h2 className="text-lg font-bold text-white">{category.title}</h2>
                        <p className="text-sm text-slate-400">{category.description}</p>
                      </div>
                    </div>
                  </div>

                  <div className="divide-y divide-gray-800">
                    {categoryDocs.map(doc => (
                      <button
                        key={doc.id}
                        onClick={() => setSelectedDocument(doc)}
                        className="w-full px-5 py-4 hover:bg-[#1a1d24] transition-colors text-left group"
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div className="text-slate-500 group-hover:text-[#f0b90b] transition-colors">
                              {DOCUMENT_ICONS[doc.document_type] || <FileText className="w-5 h-5" />}
                            </div>
                            <div>
                              <div className="font-medium text-white group-hover:text-[#f0b90b] transition-colors">
                                {doc.title}
                              </div>
                              <div className="text-sm text-slate-500">
                                Version {doc.version} - Updated {new Date(doc.effective_date).toLocaleDateString()}
                              </div>
                            </div>
                          </div>
                          <div className="flex items-center gap-3">
                            {acceptances[doc.id] && (
                              <span className="text-green-400 text-xs flex items-center gap-1 bg-green-500/10 px-2 py-1 rounded">
                                <CheckCircle className="w-3 h-3" />
                                Accepted
                              </span>
                            )}
                            <ChevronRight className="w-5 h-5 text-slate-500 group-hover:text-[#f0b90b] transition-colors" />
                          </div>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <div className="mt-12 bg-gradient-to-r from-[#f0b90b]/10 to-[#d9a506]/5 border border-[#f0b90b]/20 rounded-xl p-6">
          <h3 className="text-lg font-bold text-white mb-2">Need Help?</h3>
          <p className="text-slate-400 mb-4">
            If you have questions about any of our legal documents or need clarification on specific terms,
            our support team is here to help.
          </p>
          <button
            onClick={() => navigateTo('support')}
            className="inline-flex items-center gap-2 text-[#f0b90b] hover:underline"
          >
            Contact Support
            <ExternalLink className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
