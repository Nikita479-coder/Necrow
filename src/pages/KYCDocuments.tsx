import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { FileText, Image, Download, Eye, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface Document {
  id: string;
  document_type: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  uploaded_at: string;
  verified: boolean;
  verification_notes: string | null;
}

export default function KYCDocuments() {
  const { user } = useAuth();
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDoc, setSelectedDoc] = useState<string | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  useEffect(() => {
    loadDocuments();
  }, [user]);

  const loadDocuments = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('kyc_documents')
        .select('id, document_type, file_name, file_size, mime_type, uploaded_at, verified, verification_notes')
        .eq('user_id', user.id)
        .order('uploaded_at', { ascending: false });

      if (error) throw error;
      setDocuments(data || []);
    } catch (error) {
      console.error('Error loading documents:', error);
    } finally {
      setLoading(false);
    }
  };

  const viewDocument = async (docId: string) => {
    try {
      const { data, error } = await supabase
        .from('kyc_documents')
        .select('file_data, mime_type')
        .eq('id', docId)
        .single();

      if (error) throw error;

      if (data && data.file_data) {
        const uint8Array = new Uint8Array(data.file_data);
        const blob = new Blob([uint8Array], { type: data.mime_type });
        const url = URL.createObjectURL(blob);
        setImageUrl(url);
        setSelectedDoc(docId);
      }
    } catch (error) {
      console.error('Error viewing document:', error);
    }
  };

  const downloadDocument = async (docId: string, fileName: string) => {
    try {
      const { data, error } = await supabase
        .rpc('get_document_base64', { doc_id: docId })
        .single();

      if (error) throw error;

      if (data && data.file_data_base64) {
        const binaryString = atob(data.file_data_base64);
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }

        const blob = new Blob([bytes], { type: data.mime_type });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    } catch (error) {
      console.error('Error downloading document:', error);
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
  };

  const formatDocType = (type: string) => {
    const types: Record<string, string> = {
      'id_front': 'ID Front',
      'id_back': 'ID Back',
      'selfie': 'Selfie Photo',
      'face_verification': 'Face Verification',
      'proof_address': 'Proof of Address',
      'business_doc': 'Business Document'
    };
    return types[type] || type;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-80px)]">
          <div className="text-white text-xl">Loading documents...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">KYC Documents</h1>
          <p className="text-slate-400">View all your uploaded verification documents</p>
        </div>

        {documents.length === 0 ? (
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-12 text-center">
            <FileText className="w-16 h-16 text-slate-600 mx-auto mb-4" />
            <p className="text-slate-400 text-lg">No documents uploaded yet</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {documents.map((doc) => (
              <div key={doc.id} className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6 hover:border-slate-600 transition-colors">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 bg-blue-500/10 rounded-lg flex items-center justify-center">
                      <Image className="w-6 h-6 text-blue-400" />
                    </div>
                    <div>
                      <h3 className="text-white font-medium">{formatDocType(doc.document_type)}</h3>
                      <p className="text-slate-400 text-sm">{formatFileSize(doc.file_size)}</p>
                    </div>
                  </div>
                  <div className={`px-2 py-1 rounded-full text-xs font-medium ${
                    doc.verified
                      ? 'bg-green-500/10 text-green-400'
                      : 'bg-yellow-500/10 text-yellow-400'
                  }`}>
                    {doc.verified ? 'Verified' : 'Pending'}
                  </div>
                </div>

                <div className="space-y-2 mb-4">
                  <div className="text-sm text-slate-400">
                    <span className="font-medium">File:</span> {doc.file_name}
                  </div>
                  <div className="text-sm text-slate-400">
                    <span className="font-medium">Uploaded:</span> {new Date(doc.uploaded_at).toLocaleDateString()}
                  </div>
                  {doc.verification_notes && (
                    <div className="text-sm text-slate-400">
                      <span className="font-medium">Notes:</span> {doc.verification_notes}
                    </div>
                  )}
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => viewDocument(doc.id)}
                    className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
                  >
                    <Eye className="w-4 h-4" />
                    View
                  </button>
                  <button
                    onClick={() => downloadDocument(doc.id, doc.file_name)}
                    className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg font-medium transition-colors"
                  >
                    <Download className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {imageUrl && selectedDoc && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => {
          setImageUrl(null);
          setSelectedDoc(null);
        }}>
          <div className="max-w-4xl w-full bg-slate-800 rounded-xl p-4" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-white text-xl font-bold">Document Preview</h3>
              <button
                onClick={() => {
                  setImageUrl(null);
                  setSelectedDoc(null);
                }}
                className="p-2 hover:bg-slate-700 rounded-lg transition-colors"
              >
                <X className="w-6 h-6 text-white" />
              </button>
            </div>
            <img src={imageUrl} alt="Document" className="w-full h-auto rounded-lg" />
          </div>
        </div>
      )}
    </div>
  );
}
