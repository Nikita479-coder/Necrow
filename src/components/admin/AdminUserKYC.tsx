import { useState, useEffect } from 'react';
import { Shield, FileText, CheckCircle, XCircle, Clock, User, AlertTriangle, Scan } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

interface FaceVerificationResult {
  id: string;
  session_id: string;
  liveness_score: number;
  liveness_fine: boolean;
  deepfake_score: number;
  deepfake_fine: boolean;
  verification_passed: boolean;
  created_at: string;
  demographic_data: any;
}

export default function AdminUserKYC({ userId, userData, onRefresh }: Props) {
  const [documents, setDocuments] = useState<any[]>([]);
  const [faceVerification, setFaceVerification] = useState<FaceVerificationResult | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadKYCData();
  }, [userId]);

  const loadKYCData = async () => {
    setLoading(true);
    try {
      const [docsResult, faceResult] = await Promise.all([
        supabase
          .from('kyc_documents')
          .select('*')
          .eq('user_id', userId)
          .order('uploaded_at', { ascending: false }),
        supabase
          .from('otto_verification_results')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle()
      ]);

      setDocuments(docsResult.data || []);
      setFaceVerification(faceResult.data);
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
        <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
          <Scan className="w-5 h-5 text-[#f0b90b]" />
          Face Verification Results
        </h2>
        {faceVerification ? (
          <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                {faceVerification.verification_passed ? (
                  <div className="w-12 h-12 bg-green-500/20 rounded-full flex items-center justify-center">
                    <CheckCircle className="w-6 h-6 text-green-400" />
                  </div>
                ) : (
                  <div className="w-12 h-12 bg-red-500/20 rounded-full flex items-center justify-center">
                    <XCircle className="w-6 h-6 text-red-400" />
                  </div>
                )}
                <div>
                  <p className={`text-lg font-bold ${faceVerification.verification_passed ? 'text-green-400' : 'text-red-400'}`}>
                    {faceVerification.verification_passed ? 'Verification Passed' : 'Verification Failed'}
                  </p>
                  <p className="text-sm text-gray-400">
                    Completed: {new Date(faceVerification.created_at).toLocaleString()}
                  </p>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-[#1a1d23] rounded-lg p-4">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-sm text-gray-400">Liveness Detection</p>
                  <span className={`px-2 py-1 rounded text-xs font-medium ${
                    faceVerification.liveness_fine
                      ? 'bg-green-500/20 text-green-400'
                      : 'bg-red-500/20 text-red-400'
                  }`}>
                    {faceVerification.liveness_fine ? 'PASSED' : 'FAILED'}
                  </span>
                </div>
                <div className="flex items-end gap-2">
                  <p className="text-3xl font-bold text-white">
                    {(faceVerification.liveness_score * 100).toFixed(1)}%
                  </p>
                  <p className="text-sm text-gray-500 mb-1">confidence</p>
                </div>
                <div className="mt-2 h-2 bg-gray-700 rounded-full overflow-hidden">
                  <div
                    className={`h-full transition-all ${
                      faceVerification.liveness_score >= 0.75 ? 'bg-green-500' : 'bg-red-500'
                    }`}
                    style={{ width: `${faceVerification.liveness_score * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">Threshold: 75%</p>
              </div>

              <div className="bg-[#1a1d23] rounded-lg p-4">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-sm text-gray-400">Deepfake Detection</p>
                  <span className={`px-2 py-1 rounded text-xs font-medium ${
                    faceVerification.deepfake_fine
                      ? 'bg-green-500/20 text-green-400'
                      : 'bg-red-500/20 text-red-400'
                  }`}>
                    {faceVerification.deepfake_fine ? 'AUTHENTIC' : 'SUSPICIOUS'}
                  </span>
                </div>
                <div className="flex items-end gap-2">
                  <p className="text-3xl font-bold text-white">
                    {(faceVerification.deepfake_score * 100).toFixed(1)}%
                  </p>
                  <p className="text-sm text-gray-500 mb-1">authenticity</p>
                </div>
                <div className="mt-2 h-2 bg-gray-700 rounded-full overflow-hidden">
                  <div
                    className={`h-full transition-all ${
                      faceVerification.deepfake_score >= 0.75 ? 'bg-green-500' : 'bg-red-500'
                    }`}
                    style={{ width: `${faceVerification.deepfake_score * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">Threshold: 75%</p>
              </div>
            </div>

            {faceVerification.verification_passed && (
              <div className="mt-4 p-3 bg-green-500/10 border border-green-500/30 rounded-lg flex items-start gap-2">
                <CheckCircle className="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" />
                <p className="text-sm text-green-400">
                  User has passed face verification and is eligible for Level 3 (Full Verification).
                  You can approve using the "Verify Level 3" button in the Actions tab.
                </p>
              </div>
            )}

            {!faceVerification.verification_passed && (
              <div className="mt-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg flex items-start gap-2">
                <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                <p className="text-sm text-red-400">
                  Face verification failed. User may need to retry with better lighting or ensure their face is clearly visible.
                </p>
              </div>
            )}
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <User className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No face verification completed yet</p>
            <p className="text-sm text-gray-500 mt-1">User must complete face verification to qualify for Level 3</p>
          </div>
        )}
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
