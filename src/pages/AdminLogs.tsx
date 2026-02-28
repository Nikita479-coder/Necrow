import { useState, useEffect } from 'react';
import { FileText, RefreshCw } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface LogEntry {
  id: string;
  function_name: string;
  user_id: string;
  caller_id: string;
  parameters: any;
  result: any;
  error: string | null;
  created_at: string;
}

export default function AdminLogs() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const { profile } = useAuth();

  const fetchLogs = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('admin_function_logs')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) {
        console.error('Error fetching logs:', error);
      } else {
        setLogs(data || []);
      }
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (profile?.is_admin) {
      fetchLogs();
    }
  }, [profile]);

  if (!profile?.is_admin) {
    return (
      <div className="min-h-screen bg-[#0a0d10] text-white">
        <Navbar />
        <div className="max-w-7xl mx-auto px-4 py-12">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-red-400 mb-4">Access Denied</h1>
            <p className="text-gray-400">You do not have permission to view this page.</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0d10] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <FileText className="w-8 h-8 text-blue-400" />
            <h1 className="text-3xl font-bold">Admin Function Logs</h1>
          </div>
          <button
            onClick={fetchLogs}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-400 mx-auto"></div>
            <p className="text-gray-400 mt-4">Loading logs...</p>
          </div>
        ) : logs.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-12 text-center border border-gray-800">
            <FileText className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No logs found</p>
          </div>
        ) : (
          <div className="space-y-4">
            {logs.map((log) => (
              <div key={log.id} className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-lg font-bold text-white mb-1">{log.function_name}</h3>
                    <p className="text-sm text-gray-400">
                      {new Date(log.created_at).toLocaleString()}
                    </p>
                  </div>
                  {log.result?.success ? (
                    <span className="px-3 py-1 bg-green-500/10 text-green-400 rounded-full text-sm">
                      Success
                    </span>
                  ) : (
                    <span className="px-3 py-1 bg-red-500/10 text-red-400 rounded-full text-sm">
                      Failed
                    </span>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Target User ID</p>
                    <p className="text-sm text-gray-300 font-mono break-all">{log.user_id}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Caller ID</p>
                    <p className="text-sm text-gray-300 font-mono break-all">{log.caller_id}</p>
                  </div>
                </div>

                <div className="space-y-3">
                  <div>
                    <p className="text-xs text-gray-500 mb-2">Parameters</p>
                    <pre className="bg-black/50 p-3 rounded-lg text-xs text-gray-300 overflow-x-auto">
                      {JSON.stringify(log.parameters, null, 2)}
                    </pre>
                  </div>

                  <div>
                    <p className="text-xs text-gray-500 mb-2">Result</p>
                    <pre className="bg-black/50 p-3 rounded-lg text-xs text-gray-300 overflow-x-auto">
                      {JSON.stringify(log.result, null, 2)}
                    </pre>
                  </div>

                  {log.error && (
                    <div>
                      <p className="text-xs text-red-400 mb-2">Error Details</p>
                      <pre className="bg-red-500/10 p-3 rounded-lg text-xs text-red-300 overflow-x-auto">
                        {log.error}
                      </pre>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
