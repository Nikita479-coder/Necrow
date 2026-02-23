import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Shield, Image, Eye, CheckCircle2, XCircle, Clock, Search, Filter } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface User {
  id: string;
  username?: string;
  full_name: string;
  kyc_level: number;
  kyc_status: string;
}

interface Document {
  id: string;
  user_id: string;
  document_type: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  uploaded_at: string;
  verified: boolean;
  verification_notes: string | null;
  user_email?: string;
  user_name?: string;
}

interface OttoVerification {
  id: string;
  user_id: string;
  session_id: string;
  liveness_score: number;
  liveness_fine: boolean;
  deepfake_score: number;
  deepfake_fine: boolean;
  verification_passed: boolean;
  created_at: string;
  user_email?: string;
  user_name?: string;
  quality_data?: any;
}

export default function AdminKYC() {
  const { user } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [ottoVerifications, setOttoVerifications] = useState<OttoVerification[]>([]);
  const [selectedUser, setSelectedUser] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [selectedDoc, setSelectedDoc] = useState<Document | null>(null);
  const [selectedOtto, setSelectedOtto] = useState<OttoVerification | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'verified' | 'rejected'>('all');
  const [activeTab, setActiveTab] = useState<'documents' | 'otto'>('documents');
  const [verificationNotes, setVerificationNotes] = useState('');
  const [processingAction, setProcessingAction] = useState(false);
  const [bulkProcessing, setBulkProcessing] = useState(false);
  const [allLoaded, setAllLoaded] = useState(false);
  const [loadingAll, setLoadingAll] = useState(false);
  const [totalDocCount, setTotalDocCount] = useState(0);
  const [totalUserCount, setTotalUserCount] = useState(0);

  const INITIAL_LIMIT = 50;

  useEffect(() => {
    loadData(INITIAL_LIMIT);
  }, []);

  const fetchAllPaginated = async <T,>(
    table: string,
    selectQuery: string,
    orderColumn: string = 'created_at'
  ): Promise<T[]> => {
    const pageSize = 1000;
    let allData: T[] = [];
    let page = 0;
    let hasMore = true;

    while (hasMore) {
      const from = page * pageSize;
      const to = from + pageSize - 1;

      const { data, error } = await supabase
        .from(table)
        .select(selectQuery)
        .order(orderColumn, { ascending: false })
        .range(from, to);

      if (error) throw error;

      if (data && data.length > 0) {
        allData = [...allData, ...data as T[]];
        hasMore = data.length === pageSize;
        page++;
      } else {
        hasMore = false;
      }
    }

    return allData;
  };

  const enrichDocsWithUsers = (docsData: Document[], usersData: User[]) => {
    return docsData.map(doc => {
      const userInfo = usersData.find(u => u.id === doc.user_id);
      return {
        ...doc,
        user_email: userInfo?.username || doc.user_id.substring(0, 8),
        user_name: userInfo?.full_name || 'Unknown User'
      };
    });
  };

  const fetchUsersForIds = async (userIds: string[]): Promise<User[]> => {
    if (userIds.length === 0) return [];
    const unique = [...new Set(userIds)];
    const batches: User[] = [];
    for (let i = 0; i < unique.length; i += 50) {
      const batch = unique.slice(i, i + 50);
      const { data } = await supabase
        .from('user_profiles')
        .select('id, username, full_name, kyc_level, kyc_status')
        .in('id', batch);
      if (data) batches.push(...(data as User[]));
    }
    return batches;
  };

  const loadData = async (limit?: number) => {
    try {
      const { count } = await supabase
        .from('kyc_documents')
        .select('id', { count: 'exact', head: true });
      setTotalDocCount(count || 0);

      const { count: userCount } = await supabase
        .from('user_profiles')
        .select('id', { count: 'exact', head: true });
      setTotalUserCount(userCount || 0);

      let docsData: Document[];
      if (limit) {
        const { data, error } = await supabase
          .from('kyc_documents')
          .select('id, user_id, document_type, file_name, file_size, mime_type, uploaded_at, verified, verification_notes')
          .order('uploaded_at', { ascending: false })
          .range(0, limit - 1);
        if (error) throw error;
        docsData = (data || []) as Document[];
      } else {
        docsData = await fetchAllPaginated<Document>(
          'kyc_documents',
          'id, user_id, document_type, file_name, file_size, mime_type, uploaded_at, verified, verification_notes',
          'uploaded_at'
        );
        setAllLoaded(true);
      }

      const docUserIds = docsData.map(d => d.user_id);
      const usersData = await fetchUsersForIds(docUserIds);

      setUsers(usersData);
      setDocuments(enrichDocsWithUsers(docsData, usersData));

      try {
        const { data: ottoData } = await supabase
          .from('otto_verification_results')
          .select('*')
          .order('created_at', { ascending: false })
          .range(0, INITIAL_LIMIT - 1);

        if (ottoData && ottoData.length > 0) {
          const ottoUserIds = ottoData.map((v: any) => v.user_id);
          const ottoUsers = await fetchUsersForIds(ottoUserIds);
          const ottoWithUsers = (ottoData as OttoVerification[]).map(verification => {
            const userInfo = ottoUsers.find(u => u.id === verification.user_id);
            return {
              ...verification,
              user_email: userInfo?.username || verification.user_id.substring(0, 8),
              user_name: userInfo?.full_name || 'Unknown User'
            };
          });
          setOttoVerifications(ottoWithUsers);
        }
      } catch (ottoError) {
        console.error('Error loading Otto verifications:', ottoError);
      }
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadAllDocuments = async () => {
    setLoadingAll(true);
    try {
      const docsData = await fetchAllPaginated<Document>(
        'kyc_documents',
        'id, user_id, document_type, file_name, file_size, mime_type, uploaded_at, verified, verification_notes',
        'uploaded_at'
      );
      const docUserIds = docsData.map(d => d.user_id);
      const usersData = await fetchUsersForIds(docUserIds);
      setUsers(prev => {
        const existingIds = new Set(prev.map(u => u.id));
        const newUsers = usersData.filter(u => !existingIds.has(u.id));
        return [...prev, ...newUsers];
      });
      setDocuments(enrichDocsWithUsers(docsData, [...users, ...usersData]));
      setAllLoaded(true);
    } catch (error) {
      console.error('Error loading all documents:', error);
    } finally {
      setLoadingAll(false);
    }
  };

  const viewDocument = async (doc: Document) => {
    try {
      const { data, error } = await supabase
        .rpc('get_document_base64', { doc_id: doc.id })
        .single();

      if (error) throw error;

      if (data && data.file_data_base64) {
        const dataUrl = `data:${data.mime_type};base64,${data.file_data_base64}`;
        setSelectedDoc(doc);
        setImageUrl(dataUrl);
        setVerificationNotes(doc.verification_notes || '');
      } else {
        alert('No file data found');
      }
    } catch (error) {
      console.error('Error viewing document:', error);
      alert(`Failed to load document: ${error}`);
    }
  };

  const updateVerification = async (docId: string, verified: boolean, notes: string) => {
    setProcessingAction(true);
    try {
      const doc = documents.find(d => d.id === docId);
      if (!doc) {
        alert('Document not found');
        return;
      }

      if (verified) {
        const { error } = await supabase
          .from('kyc_documents')
          .update({
            verified: true,
            verification_notes: notes || 'Approved by admin',
            updated_at: new Date().toISOString()
          })
          .eq('id', docId);

        if (error) {
          console.error('Error updating document:', error);
          alert(`Failed to update document: ${error.message}`);
          return;
        }
      } else {
        const rejectionReason = notes || 'Your KYC has been rejected. Please submit new documents with clearer images.';
        const { data, error } = await supabase.rpc('admin_reject_kyc_full_reset', {
          p_user_id: doc.user_id,
          p_rejection_reason: rejectionReason
        });

        if (error) {
          console.error('Error performing full KYC reset:', error);
          alert(`Failed to reject KYC: ${error.message}`);
          return;
        }

        if (data && !data.success) {
          alert(`Failed to reject KYC: ${data.error}`);
          return;
        }
      }

      await loadData(allLoaded ? undefined : INITIAL_LIMIT);
      setImageUrl(null);
      setSelectedDoc(null);
      setVerificationNotes('');
      alert(verified ? 'Document approved successfully' : 'KYC rejected and reset - user can now submit fresh documents');
    } catch (error: any) {
      console.error('Error updating verification:', error);
      alert(`Error: ${error.message || 'Failed to update verification'}`);
    } finally {
      setProcessingAction(false);
    }
  };

  const bulkApprovePending = async () => {
    const pendingDocs = documents.filter(doc => getDocStatus(doc) === 'pending');

    if (pendingDocs.length === 0) {
      alert('No pending documents to approve');
      return;
    }

    const confirmed = confirm(
      `Are you sure you want to approve all ${pendingDocs.length} pending KYC documents?\n\nThis action cannot be undone.`
    );

    if (!confirmed) return;

    setBulkProcessing(true);
    let successCount = 0;
    let failCount = 0;

    for (const doc of pendingDocs) {
      try {
        const { error } = await supabase
          .from('kyc_documents')
          .update({
            verified: true,
            verification_notes: 'Bulk approved by admin',
            updated_at: new Date().toISOString()
          })
          .eq('id', doc.id);

        if (error) {
          console.error(`Error approving document ${doc.id}:`, error);
          failCount++;
        } else {
          successCount++;
        }
      } catch (error) {
        console.error(`Error approving document ${doc.id}:`, error);
        failCount++;
      }

      // Small delay to avoid overwhelming the database
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    setBulkProcessing(false);
    await loadData(allLoaded ? undefined : INITIAL_LIMIT);

    alert(
      `Bulk approval completed!\n\nApproved: ${successCount}\nFailed: ${failCount}\n\nNote: KYC levels will be automatically upgraded based on verified documents.`
    );
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
      'selfie': 'Selfie',
      'face_verification': 'Face Verification',
      'proof_address': 'Proof of Address',
      'business_doc': 'Business Document'
    };
    return types[type] || type;
  };

  const getDocStatus = (doc: Document): 'verified' | 'rejected' | 'pending' => {
    if (doc.verified) return 'verified';
    if (doc.verification_notes && doc.verification_notes.toLowerCase().includes('reject')) return 'rejected';
    return 'pending';
  };

  const filteredDocuments = documents.filter(doc => {
    const matchesSearch =
      doc.user_email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      doc.user_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      doc.document_type.toLowerCase().includes(searchTerm.toLowerCase());

    const docStatus = getDocStatus(doc);
    const matchesStatus = statusFilter === 'all' || statusFilter === docStatus;

    const matchesUser = !selectedUser || doc.user_id === selectedUser;

    return matchesSearch && matchesStatus && matchesUser;
  });

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-80px)]">
          <div className="text-white text-xl">Loading admin panel...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2 flex items-center gap-3">
            <Shield className="w-8 h-8 text-blue-400" />
            KYC Admin Panel
          </h1>
          <p className="text-slate-400">Review and verify user KYC documents</p>
        </div>

        {/* Tabs */}
        <div className="flex gap-4 mb-6">
          <button
            onClick={() => setActiveTab('documents')}
            className={`px-6 py-3 rounded-lg font-medium transition-all ${
              activeTab === 'documents'
                ? 'bg-blue-600 text-white'
                : 'bg-slate-800/50 text-slate-400 hover:bg-slate-700/50'
            }`}
          >
            KYC Documents ({documents.length})
          </button>
          <button
            onClick={() => setActiveTab('otto')}
            className={`px-6 py-3 rounded-lg font-medium transition-all ${
              activeTab === 'otto'
                ? 'bg-blue-600 text-white'
                : 'bg-slate-800/50 text-slate-400 hover:bg-slate-700/50'
            }`}
          >
            Face Verifications ({ottoVerifications.length})
          </button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6">
            <div className="text-slate-400 text-sm mb-1">Total Users</div>
            <div className="text-3xl font-bold text-white">{totalUserCount}</div>
          </div>
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6">
            <div className="text-slate-400 text-sm mb-1">Total Documents</div>
            <div className="text-3xl font-bold text-white">{totalDocCount}</div>
          </div>
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6">
            <div className="text-slate-400 text-sm mb-1">Pending Review</div>
            <div className="text-3xl font-bold text-yellow-400">
              {documents.filter(d => getDocStatus(d) === 'pending').length}
            </div>
          </div>
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6">
            <div className="text-slate-400 text-sm mb-1">Verified</div>
            <div className="text-3xl font-bold text-green-400">
              {documents.filter(d => getDocStatus(d) === 'verified').length}
            </div>
          </div>
          <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6">
            <div className="text-slate-400 text-sm mb-1">Rejected</div>
            <div className="text-3xl font-bold text-red-400">
              {documents.filter(d => getDocStatus(d) === 'rejected').length}
            </div>
          </div>
        </div>

        {/* Bulk Actions */}
        <div className="bg-gradient-to-r from-blue-600/10 to-blue-800/10 backdrop-blur-sm rounded-xl border border-blue-600/30 p-4 mb-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div>
              <h3 className="text-white font-semibold text-lg mb-1">Bulk Actions</h3>
              <p className="text-slate-400 text-sm">
                Approve all pending KYC documents at once (rejected documents are skipped)
              </p>
            </div>
            <button
              onClick={bulkApprovePending}
              disabled={bulkProcessing || documents.filter(doc => getDocStatus(doc) === 'pending').length === 0}
              className="px-6 py-3 bg-green-600 hover:bg-green-700 disabled:bg-slate-600 disabled:cursor-not-allowed text-white rounded-lg font-semibold transition-colors flex items-center gap-2 whitespace-nowrap"
            >
              <CheckCircle2 className="w-5 h-5" />
              {bulkProcessing ? 'Processing...' : `Approve All Pending (${documents.filter(doc => getDocStatus(doc) === 'pending').length})`}
            </button>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-4 mb-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400" />
              <input
                type="text"
                placeholder="Search by email or name..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:border-blue-500"
              />
            </div>

            <select
              value={selectedUser || ''}
              onChange={(e) => setSelectedUser(e.target.value || null)}
              className="px-4 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
            >
              <option value="">All Users</option>
              {users.map(user => (
                <option key={user.id} value={user.id}>
                  {user.username || user.id.substring(0, 8)} - {user.full_name}
                </option>
              ))}
            </select>

            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="px-4 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
            >
              <option value="all">All Status</option>
              <option value="pending">Pending</option>
              <option value="verified">Verified</option>
              <option value="rejected">Rejected</option>
            </select>
          </div>
        </div>

        {/* Content based on active tab */}
        {activeTab === 'documents' && (
        <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-700/50">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    User
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Document Type
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    File Info
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Uploaded
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700">
                {filteredDocuments.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-slate-400">
                      No documents found
                    </td>
                  </tr>
                ) : (
                  filteredDocuments.map((doc) => (
                    <tr key={doc.id} className="hover:bg-slate-700/30 transition-colors">
                      <td className="px-6 py-4">
                        <div className="text-white font-medium">{doc.user_name}</div>
                        <div className="text-slate-400 text-sm">{doc.user_email}</div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <Image className="w-4 h-4 text-blue-400" />
                          <span className="text-white">{formatDocType(doc.document_type)}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="text-white text-sm">{doc.file_name}</div>
                        <div className="text-slate-400 text-xs">{formatFileSize(doc.file_size)}</div>
                      </td>
                      <td className="px-6 py-4 text-slate-300 text-sm">
                        {new Date(doc.uploaded_at).toLocaleString()}
                      </td>
                      <td className="px-6 py-4">
                        {(() => {
                          const status = getDocStatus(doc);
                          if (status === 'verified') {
                            return (
                              <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-green-500/10 text-green-400">
                                <CheckCircle2 className="w-3 h-3" />
                                Verified
                              </span>
                            );
                          } else if (status === 'rejected') {
                            return (
                              <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-red-500/10 text-red-400">
                                <XCircle className="w-3 h-3" />
                                Rejected
                              </span>
                            );
                          } else {
                            return (
                              <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-yellow-500/10 text-yellow-400">
                                <Clock className="w-3 h-3" />
                                Pending
                              </span>
                            );
                          }
                        })()}
                      </td>
                      <td className="px-6 py-4">
                        <button
                          onClick={() => viewDocument(doc)}
                          className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors flex items-center gap-2 text-sm"
                        >
                          <Eye className="w-4 h-4" />
                          Review
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {!allLoaded && totalDocCount > INITIAL_LIMIT && (
            <div className="border-t border-slate-700 px-6 py-4 flex items-center justify-between bg-slate-800/30">
              <span className="text-slate-400 text-sm">
                Showing {documents.length} of {totalDocCount} documents
              </span>
              <button
                onClick={loadAllDocuments}
                disabled={loadingAll}
                className="px-5 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-600/50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors text-sm"
              >
                {loadingAll ? 'Loading...' : `Load All ${totalDocCount} Documents`}
              </button>
            </div>
          )}
        </div>
        )}

        {/* Otto AI Verifications Table */}
        {activeTab === 'otto' && (
        <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-700/50">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    User
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Liveness
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Deepfake
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Overall Result
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Date
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-medium text-slate-300 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700">
                {ottoVerifications.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-slate-400">
                      No face verifications found
                    </td>
                  </tr>
                ) : (
                  ottoVerifications
                    .filter(v => !selectedUser || v.user_id === selectedUser)
                    .map((verification) => (
                    <tr key={verification.id} className="hover:bg-slate-700/30 transition-colors">
                      <td className="px-6 py-4">
                        <div className="text-white font-medium">{verification.user_name}</div>
                        <div className="text-slate-400 text-sm">{verification.user_email}</div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <div className={`w-3 h-3 rounded-full ${
                            verification.liveness_fine ? 'bg-green-500' : 'bg-red-500'
                          }`} />
                          <span className={`font-medium ${
                            verification.liveness_fine ? 'text-green-400' : 'text-red-400'
                          }`}>
                            {(verification.liveness_score * 100).toFixed(1)}%
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <div className={`w-3 h-3 rounded-full ${
                            verification.deepfake_fine ? 'bg-green-500' : 'bg-red-500'
                          }`} />
                          <span className={`font-medium ${
                            verification.deepfake_fine ? 'text-green-400' : 'text-red-400'
                          }`}>
                            {(verification.deepfake_score * 100).toFixed(1)}%
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        {verification.verification_passed ? (
                          <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-green-500/10 text-green-400">
                            <CheckCircle2 className="w-3 h-3" />
                            Passed
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-red-500/10 text-red-400">
                            <XCircle className="w-3 h-3" />
                            Failed
                          </span>
                        )}
                      </td>
                      <td className="px-6 py-4 text-slate-300 text-sm">
                        {new Date(verification.created_at).toLocaleString()}
                      </td>
                      <td className="px-6 py-4">
                        <button
                          onClick={() => setSelectedOtto(verification)}
                          className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors flex items-center gap-2 text-sm"
                        >
                          <Eye className="w-4 h-4" />
                          Details
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
        )}
      </div>

      {/* Document Review Modal */}
      {imageUrl && selectedDoc && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="max-w-5xl w-full bg-slate-800 rounded-xl p-6">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-white text-2xl font-bold mb-1">
                  {formatDocType(selectedDoc.document_type)}
                </h3>
                <p className="text-slate-400">
                  {selectedDoc.user_name} ({selectedDoc.user_email})
                </p>
              </div>
              <button
                onClick={() => {
                  setImageUrl(null);
                  setSelectedDoc(null);
                }}
                className="p-2 hover:bg-slate-700 rounded-lg transition-colors"
              >
                <XCircle className="w-6 h-6 text-white" />
              </button>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <div className="lg:col-span-2">
                {imageUrl ? (
                  <img
                    src={imageUrl}
                    alt="Document"
                    className="w-full h-auto rounded-lg border border-slate-700"
                    onLoad={() => console.log('Image loaded successfully')}
                    onError={(e) => console.error('Image failed to load', e)}
                  />
                ) : (
                  <div className="w-full h-96 bg-slate-700/50 rounded-lg border border-slate-700 flex items-center justify-center">
                    <p className="text-slate-400">Loading document...</p>
                  </div>
                )}
              </div>

              <div className="space-y-4">
                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h4 className="text-white font-medium mb-3">Document Details</h4>
                  <div className="space-y-2 text-sm">
                    <div>
                      <span className="text-slate-400">File:</span>
                      <span className="text-white ml-2">{selectedDoc.file_name}</span>
                    </div>
                    <div>
                      <span className="text-slate-400">Size:</span>
                      <span className="text-white ml-2">{formatFileSize(selectedDoc.file_size)}</span>
                    </div>
                    <div>
                      <span className="text-slate-400">Uploaded:</span>
                      <span className="text-white ml-2">
                        {new Date(selectedDoc.uploaded_at).toLocaleString()}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-400">Status:</span>
                      <span className={`ml-2 font-medium ${selectedDoc.verified ? 'text-green-400' : 'text-yellow-400'}`}>
                        {selectedDoc.verified ? 'Verified' : 'Pending'}
                      </span>
                    </div>
                  </div>
                </div>

                {selectedDoc.verification_notes && (
                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h4 className="text-white font-medium mb-2">Previous Notes</h4>
                    <p className="text-slate-300 text-sm">{selectedDoc.verification_notes}</p>
                  </div>
                )}

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h4 className="text-white font-medium mb-3">Verification Actions</h4>

                  <textarea
                    value={verificationNotes}
                    onChange={(e) => setVerificationNotes(e.target.value)}
                    placeholder="Add verification notes (e.g., reason for rejection)..."
                    className="w-full px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:border-blue-500 mb-3 text-sm"
                    rows={3}
                  />

                  <div className="flex gap-2">
                    <button
                      onClick={() => updateVerification(selectedDoc.id, true, verificationNotes)}
                      disabled={processingAction}
                      className="flex-1 px-4 py-2 bg-green-600 hover:bg-green-700 disabled:bg-green-600/50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      {processingAction ? 'Processing...' : 'Approve'}
                    </button>
                    <button
                      onClick={() => updateVerification(selectedDoc.id, false, verificationNotes)}
                      disabled={processingAction}
                      className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-red-600/50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
                    >
                      <XCircle className="w-4 h-4" />
                      {processingAction ? 'Processing...' : 'Reject'}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Otto Verification Details Modal */}
      {selectedOtto && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="max-w-3xl w-full bg-slate-800 rounded-xl p-6">
            <div className="flex justify-between items-start mb-6">
              <div>
                <h3 className="text-white text-2xl font-bold mb-1">
                  Face Verification Details
                </h3>
                <p className="text-slate-400">
                  {selectedOtto.user_name} ({selectedOtto.user_email})
                </p>
              </div>
              <button
                onClick={() => setSelectedOtto(null)}
                className="p-2 hover:bg-slate-700 rounded-lg transition-colors"
              >
                <XCircle className="w-6 h-6 text-white" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Overall Status */}
              <div className={`rounded-lg p-4 border-2 ${
                selectedOtto.verification_passed
                  ? 'bg-green-900/20 border-green-600/30'
                  : 'bg-red-900/20 border-red-600/30'
              }`}>
                <div className="flex items-center gap-3">
                  {selectedOtto.verification_passed ? (
                    <CheckCircle2 className="w-8 h-8 text-green-400" />
                  ) : (
                    <XCircle className="w-8 h-8 text-red-400" />
                  )}
                  <div>
                    <h4 className={`text-lg font-bold ${
                      selectedOtto.verification_passed ? 'text-green-400' : 'text-red-400'
                    }`}>
                      Verification {selectedOtto.verification_passed ? 'Passed' : 'Failed'}
                    </h4>
                    <p className="text-slate-300 text-sm">
                      Completed on {new Date(selectedOtto.created_at).toLocaleString()}
                    </p>
                  </div>
                </div>
              </div>

              {/* Liveness Detection */}
              <div className="bg-slate-700/50 rounded-lg p-4">
                <h4 className="text-white font-semibold mb-3 flex items-center gap-2">
                  <Shield className="w-5 h-5 text-blue-400" />
                  Liveness Detection
                </h4>
                <div className="space-y-2">
                  <div className="flex justify-between items-center">
                    <span className="text-slate-300">Score:</span>
                    <span className={`font-bold ${
                      selectedOtto.liveness_fine ? 'text-green-400' : 'text-red-400'
                    }`}>
                      {(selectedOtto.liveness_score * 100).toFixed(2)}%
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-300">Status:</span>
                    <span className={`font-semibold ${
                      selectedOtto.liveness_fine ? 'text-green-400' : 'text-red-400'
                    }`}>
                      {selectedOtto.liveness_fine ? 'PASSED' : 'FAILED'}
                    </span>
                  </div>
                  <div className="w-full bg-slate-600 rounded-full h-2 mt-2">
                    <div
                      className={`h-2 rounded-full transition-all ${
                        selectedOtto.liveness_fine ? 'bg-green-500' : 'bg-red-500'
                      }`}
                      style={{ width: `${selectedOtto.liveness_score * 100}%` }}
                    />
                  </div>
                </div>
              </div>

              {/* Deepfake Detection */}
              <div className="bg-slate-700/50 rounded-lg p-4">
                <h4 className="text-white font-semibold mb-3 flex items-center gap-2">
                  <Shield className="w-5 h-5 text-purple-400" />
                  Deepfake Detection
                </h4>
                <div className="space-y-2">
                  <div className="flex justify-between items-center">
                    <span className="text-slate-300">Score:</span>
                    <span className={`font-bold ${
                      selectedOtto.deepfake_fine ? 'text-green-400' : 'text-red-400'
                    }`}>
                      {(selectedOtto.deepfake_score * 100).toFixed(2)}%
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-300">Status:</span>
                    <span className={`font-semibold ${
                      selectedOtto.deepfake_fine ? 'text-green-400' : 'text-red-400'
                    }`}>
                      {selectedOtto.deepfake_fine ? 'PASSED' : 'FAILED'}
                    </span>
                  </div>
                  <div className="w-full bg-slate-600 rounded-full h-2 mt-2">
                    <div
                      className={`h-2 rounded-full transition-all ${
                        selectedOtto.deepfake_fine ? 'bg-green-500' : 'bg-red-500'
                      }`}
                      style={{ width: `${selectedOtto.deepfake_score * 100}%` }}
                    />
                  </div>
                </div>
              </div>

              {/* Quality Metrics */}
              {selectedOtto.quality_data && (
                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h4 className="text-white font-semibold mb-3">Quality Metrics</h4>
                  <div className="grid grid-cols-2 gap-3 text-sm">
                    {Object.entries(selectedOtto.quality_data).slice(0, 8).map(([key, value]: [string, any]) => (
                      <div key={key} className="flex justify-between">
                        <span className="text-slate-400 capitalize">{key.replace(/_/g, ' ')}:</span>
                        <span className={`font-medium ${
                          value?.fine === true ? 'text-green-400' :
                          value?.fine === false ? 'text-red-400' :
                          'text-slate-300'
                        }`}>
                          {typeof value === 'object' && value?.fine !== undefined
                            ? value.fine ? 'PASS' : 'FAIL'
                            : typeof value === 'number'
                            ? value.toFixed(2)
                            : String(value)}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Session ID */}
              <div className="bg-slate-700/50 rounded-lg p-4">
                <h4 className="text-white font-semibold mb-2">Session Information</h4>
                <div className="text-sm">
                  <span className="text-slate-400">Session ID:</span>
                  <code className="ml-2 text-slate-300 bg-slate-900/50 px-2 py-1 rounded text-xs">
                    {selectedOtto.session_id}
                  </code>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
