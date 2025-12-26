import { useState, useEffect } from 'react';
import { Shield, FileText, CheckCircle, XCircle, Clock } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

export default function AdminUserKYC({ userId, userData, onRefresh }: Props) {
  const [documents, setDocuments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadKYCData();
  }, [userId]);

  const loadKYCData = async () => {
    setLoading(true);
    try {
      const { data } = await supabase
        .from('kyc_documents')
        .select('*')
        .eq('user_id', userId)
        .order('uploaded_at', { ascending: false });

      setDocuments(data || []);
    } catch (error) {
      console.error('Error loading KYC data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'verified':
      case 'approved':
        return <CheckCircle className="w-5 h-5 text-green-400" />;
      case 'rejected':
        return <XCircle className="w-5 h-5 text-red-400" />;
      case 'pending':
        return <Clock className="w-5 h-5 text-yellow-400" />;
      default:
        return <FileText className="w-5 h-5 text-gray-400" />;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'verified':
      case 'approved':
        return 'bg-green-500/20 text-green-400 border-green-500/30';
      case 'rejected':
        return 'bg-red-500/20 text-red-400 border-red-500/30';
      case 'pending':
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      default:
        return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">KYC Status</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Shield className="w-5 h-5 text-[#f0b90b]" />
                <p className="text-sm text-gray-400">KYC Status</p>
              </div>
              <span className={`inline-flex items-center px-3 py-1 rounded-lg border text-sm font-medium ${getStatusBadge(userData?.profile?.kyc_status)}`}>
                {userData?.profile?.kyc_status?.toUpperCase() || 'NONE'}
              </span>
            </div>

            <div>
              <p className="text-sm text-gray-400 mb-2">KYC Level</p>
              <p className="text-2xl font-bold text-white">{userData?.profile?.kyc_level || 0}</p>
            </div>

            <div>
              <div className="flex items-center gap-2 mb-2">
                <FileText className="w-5 h-5 text-[#f0b90b]" />
                <p className="text-sm text-gray-400">Documents Submitted</p>
              </div>
              <p className="text-2xl font-bold text-white">{documents.length}</p>
            </div>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Submitted Documents</h2>
        {documents.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <FileText className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No documents submitted yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {documents.map((doc) => (
              <div key={doc.id} className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-start gap-3">
                    {getStatusIcon(doc.status)}
                    <div>
                      <h3 className="text-lg font-bold text-white mb-1">{doc.document_type}</h3>
                      <p className="text-sm text-gray-400">
                        Uploaded: {new Date(doc.uploaded_at).toLocaleString()}
                      </p>
                    </div>
                  </div>
                  <span className={`px-3 py-1 rounded-lg border text-xs font-medium ${getStatusBadge(doc.status)}`}>
                    {doc.status}
                  </span>
                </div>

                {doc.rejection_reason && (
                  <div className="mt-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
                    <p className="text-sm text-red-400">
                      <span className="font-bold">Rejection Reason:</span> {doc.rejection_reason}
                    </p>
                  </div>
                )}

                {doc.notes && (
                  <div className="mt-3 p-3 bg-gray-800/50 rounded-lg">
                    <p className="text-sm text-gray-400">
                      <span className="font-bold">Notes:</span> {doc.notes}
                    </p>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
