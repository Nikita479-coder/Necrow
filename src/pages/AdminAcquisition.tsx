import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';
import {
  ArrowLeft, Users, TrendingUp, Globe, Smartphone, Monitor,
  Tablet, BarChart3, PieChart, Calendar, Filter, Download,
  Link as LinkIcon, Plus, Copy, ExternalLink, Trash2, Eye,
  Facebook, Instagram, Twitter, Youtube, Search, RefreshCw,
  MousePointer, UserPlus, Percent, Activity
} from 'lucide-react';
import { supabase } from '../lib/supabase';

interface VisitorAnalytics {
  total_visitors: number;
  unique_visitors: number;
  total_signups: number;
  overall_conversion_rate: number;
  total_page_views: number;
  sources: {
    source: string;
    visitors: number;
    signups: number;
    conversion_rate: number;
    page_views: number;
  }[];
  campaigns: {
    campaign: string;
    source: string;
    visitors: number;
    signups: number;
    conversion_rate: number;
  }[];
  devices: {
    device: string;
    visitors: number;
    signups: number;
  }[];
  daily_stats: {
    date: string;
    visitors: number;
    signups: number;
  }[];
}

interface TrackingLink {
  id: string;
  name: string;
  utm_source: string;
  utm_medium: string;
  utm_campaign: string;
  utm_content: string;
  utm_term: string;
  short_code: string;
  destination_url: string;
  clicks: number;
  conversions: number;
  is_active: boolean;
  created_at: string;
}

interface VisitorSession {
  id: string;
  session_id: string;
  user_id: string | null;
  utm_source: string | null;
  utm_medium: string | null;
  utm_campaign: string | null;
  utm_content: string | null;
  utm_term: string | null;
  referrer_url: string | null;
  referrer_domain: string | null;
  landing_page: string | null;
  device_type: string | null;
  browser: string | null;
  os: string | null;
  country: string | null;
  city: string | null;
  ip_address: string | null;
  first_visit_at: string;
  last_visit_at: string;
  page_views: number;
  converted: boolean;
  conversion_date: string | null;
  email: string | null;
  full_name: string | null;
}

function AdminAcquisition() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'overview' | 'sources' | 'campaigns' | 'links' | 'visitors'>('overview');
  const [dateRange, setDateRange] = useState('30');
  const [analytics, setAnalytics] = useState<VisitorAnalytics | null>(null);
  const [trackingLinks, setTrackingLinks] = useState<TrackingLink[]>([]);
  const [visitors, setVisitors] = useState<VisitorSession[]>([]);
  const [showCreateLink, setShowCreateLink] = useState(false);
  const [newLink, setNewLink] = useState({
    name: '',
    utm_source: '',
    utm_medium: '',
    utm_campaign: '',
    utm_content: '',
    utm_term: '',
    destination_url: '/'
  });
  const [visitorSearch, setVisitorSearch] = useState('');
  const [visitorFilter, setVisitorFilter] = useState<'all' | 'converted' | 'not_converted'>('all');
  const [copiedLink, setCopiedLink] = useState<string | null>(null);
  const [selectedSource, setSelectedSource] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, [dateRange]);

  const loadData = async () => {
    setLoading(true);
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(dateRange));

    try {
      const [analyticsRes, linksRes, visitorsRes] = await Promise.all([
        supabase.rpc('get_visitor_analytics', {
          p_start_date: startDate.toISOString(),
          p_end_date: new Date().toISOString()
        }),
        supabase.from('campaign_tracking_links').select('*').order('created_at', { ascending: false }),
        supabase.rpc('get_enriched_visitor_sessions', {
          p_start_date: startDate.toISOString(),
          p_limit: 500
        })
      ]);

      if (analyticsRes.data) setAnalytics(analyticsRes.data);
      if (linksRes.data) setTrackingLinks(linksRes.data);
      if (visitorsRes.data) setVisitors(visitorsRes.data);
    } catch (error) {
      console.error('Failed to load acquisition data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getSourceIcon = (source: string) => {
    const s = source?.toLowerCase() || '';
    if (s.includes('facebook') || s.includes('fb')) return <Facebook className="w-4 h-4 text-blue-500" />;
    if (s.includes('instagram')) return <Instagram className="w-4 h-4 text-pink-500" />;
    if (s.includes('twitter') || s.includes('x.com')) return <Twitter className="w-4 h-4 text-sky-400" />;
    if (s.includes('youtube')) return <Youtube className="w-4 h-4 text-red-500" />;
    if (s.includes('tiktok')) return <span className="text-sm font-bold">TT</span>;
    if (s.includes('google')) return <Search className="w-4 h-4 text-blue-400" />;
    return <Globe className="w-4 h-4 text-gray-400" />;
  };

  const getDeviceIcon = (device: string) => {
    const d = device?.toLowerCase() || '';
    if (d === 'mobile') return <Smartphone className="w-4 h-4" />;
    if (d === 'tablet') return <Tablet className="w-4 h-4" />;
    return <Monitor className="w-4 h-4" />;
  };

  const createTrackingLink = async () => {
    if (!newLink.name || !newLink.utm_source) return;

    const shortCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    const { error } = await supabase
      .from('campaign_tracking_links')
      .insert({
        ...newLink,
        short_code: shortCode,
        created_by: user?.id
      });

    if (!error) {
      setShowCreateLink(false);
      setNewLink({
        name: '',
        utm_source: '',
        utm_medium: '',
        utm_campaign: '',
        utm_content: '',
        utm_term: '',
        destination_url: '/'
      });
      loadData();
    }
  };

  const getTrackingUrl = (link: TrackingLink) => {
    const baseUrl = window.location.origin;
    const params = new URLSearchParams();
    if (link.utm_source) params.set('utm_source', link.utm_source);
    if (link.utm_medium) params.set('utm_medium', link.utm_medium);
    if (link.utm_campaign) params.set('utm_campaign', link.utm_campaign);
    if (link.utm_content) params.set('utm_content', link.utm_content);
    if (link.utm_term) params.set('utm_term', link.utm_term);
    return `${baseUrl}${link.destination_url}?${params.toString()}`;
  };

  const copyTrackingUrl = (link: TrackingLink) => {
    const url = getTrackingUrl(link);
    navigator.clipboard.writeText(url);
    setCopiedLink(link.id);
    setTimeout(() => setCopiedLink(null), 2000);
  };

  const deleteTrackingLink = async (id: string) => {
    const { error } = await supabase
      .from('campaign_tracking_links')
      .delete()
      .eq('id', id);

    if (!error) loadData();
  };

  const getVisitorSource = (visitor: VisitorSession) => {
    const source = visitor.utm_source || visitor.referrer_domain || null;
    return source ? source.toLowerCase() : 'direct';
  };

  const filteredVisitors = visitors.filter(v => {
    if (visitorFilter === 'converted' && !v.converted) return false;
    if (visitorFilter === 'not_converted' && v.converted) return false;

    if (selectedSource) {
      const visitorSource = getVisitorSource(v);
      const targetSource = selectedSource.toLowerCase();

      // Handle 'direct' as a special case for null/empty sources
      if (targetSource === 'direct') {
        if (!v.utm_source && !v.referrer_domain) return true;
        return false;
      }

      // Check if visitor source matches or contains the selected source
      if (visitorSource !== targetSource && !visitorSource.includes(targetSource)) {
        return false;
      }
    }

    if (!visitorSearch) return true;
    const search = visitorSearch.toLowerCase();
    return (
      v.email?.toLowerCase().includes(search) ||
      v.full_name?.toLowerCase().includes(search) ||
      v.utm_source?.toLowerCase().includes(search) ||
      v.utm_campaign?.toLowerCase().includes(search) ||
      v.referrer_domain?.toLowerCase().includes(search) ||
      v.session_id?.toLowerCase().includes(search) ||
      v.country?.toLowerCase().includes(search) ||
      v.city?.toLowerCase().includes(search) ||
      v.ip_address?.toLowerCase().includes(search)
    );
  });

  const sourceColors: Record<string, string> = {
    facebook: 'bg-blue-500',
    instagram: 'bg-gradient-to-r from-pink-500 to-orange-500',
    tiktok: 'bg-black',
    twitter: 'bg-sky-500',
    google: 'bg-blue-600',
    youtube: 'bg-red-600',
    direct: 'bg-gray-500',
    organic: 'bg-green-500'
  };

  return (
    <div className="min-h-screen bg-[#0a0b0f]">
      <div className="bg-[#13141b] border-b border-gray-800 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigateTo('admindashboard')}
              className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-gray-400" />
            </button>
            <div>
              <h1 className="text-xl font-bold text-white">User Acquisition</h1>
              <p className="text-sm text-gray-400">Track visitors, signups, and conversion rates</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value)}
              className="bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white text-sm"
            >
              <option value="7">Last 7 days</option>
              <option value="30">Last 30 days</option>
              <option value="90">Last 90 days</option>
              <option value="365">Last year</option>
            </select>
            <button
              onClick={loadData}
              className="p-2 bg-[#1a1d29] hover:bg-[#252837] rounded-lg transition-colors"
            >
              <RefreshCw className="w-5 h-5 text-gray-400" />
            </button>
          </div>
        </div>
      </div>

      <div className="border-b border-gray-800">
        <div className="px-6 flex gap-1">
          {[
            { id: 'overview', label: 'Overview', icon: PieChart },
            { id: 'sources', label: 'Sources', icon: Globe },
            { id: 'campaigns', label: 'Campaigns', icon: BarChart3 },
            { id: 'links', label: 'Tracking Links', icon: LinkIcon },
            { id: 'visitors', label: 'All Visitors', icon: Users }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.id
                  ? 'text-[#f0b90b] border-[#f0b90b]'
                  : 'text-gray-400 border-transparent hover:text-white'
              }`}
            >
              <tab.icon className="w-4 h-4" />
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      <div className="p-6">
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="w-8 h-8 border-2 border-[#f0b90b] border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <>
            {activeTab === 'overview' && analytics && (
              <div className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-10 h-10 bg-blue-500/10 rounded-lg flex items-center justify-center">
                        <MousePointer className="w-5 h-5 text-blue-500" />
                      </div>
                      <span className="text-gray-400 text-sm">Total Visitors</span>
                    </div>
                    <div className="text-3xl font-bold text-white">{analytics.total_visitors.toLocaleString()}</div>
                    <div className="text-sm text-gray-500 mt-1">{analytics.total_page_views.toLocaleString()} page views</div>
                  </div>

                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-10 h-10 bg-green-500/10 rounded-lg flex items-center justify-center">
                        <UserPlus className="w-5 h-5 text-green-500" />
                      </div>
                      <span className="text-gray-400 text-sm">Total Signups</span>
                    </div>
                    <div className="text-3xl font-bold text-white">{analytics.total_signups.toLocaleString()}</div>
                    <div className="text-sm text-green-400 mt-1">Converted visitors</div>
                  </div>

                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-10 h-10 bg-[#f0b90b]/10 rounded-lg flex items-center justify-center">
                        <Percent className="w-5 h-5 text-[#f0b90b]" />
                      </div>
                      <span className="text-gray-400 text-sm">Conversion Rate</span>
                    </div>
                    <div className="text-3xl font-bold text-white">{analytics.overall_conversion_rate || 0}%</div>
                    <div className="text-sm text-gray-500 mt-1">Visitors to signups</div>
                  </div>

                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-10 h-10 bg-purple-500/10 rounded-lg flex items-center justify-center">
                        <Activity className="w-5 h-5 text-purple-500" />
                      </div>
                      <span className="text-gray-400 text-sm">Avg Pages/Visit</span>
                    </div>
                    <div className="text-3xl font-bold text-white">
                      {analytics.total_visitors > 0
                        ? (analytics.total_page_views / analytics.total_visitors).toFixed(1)
                        : 0}
                    </div>
                    <div className="text-sm text-gray-500 mt-1">Engagement metric</div>
                  </div>

                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-10 h-10 bg-red-500/10 rounded-lg flex items-center justify-center">
                        <Users className="w-5 h-5 text-red-500" />
                      </div>
                      <span className="text-gray-400 text-sm">Not Converted</span>
                    </div>
                    <div className="text-3xl font-bold text-white">
                      {(analytics.total_visitors - analytics.total_signups).toLocaleString()}
                    </div>
                    <div className="text-sm text-gray-500 mt-1">Potential users</div>
                  </div>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-4">Traffic Sources</h3>
                    <div className="space-y-3">
                      {analytics.sources.slice(0, 10).map((source, index) => (
                        <div
                          key={index}
                          className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-800/50 cursor-pointer transition-colors"
                          onClick={() => {
                            setSelectedSource(source.source || 'direct');
                            setActiveTab('visitors');
                          }}
                        >
                          <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                            sourceColors[source.source?.toLowerCase()] || 'bg-gray-700'
                          }`}>
                            {getSourceIcon(source.source)}
                          </div>
                          <div className="flex-1">
                            <div className="flex items-center justify-between mb-1">
                              <span className="text-white font-medium capitalize">
                                {source.source || 'Direct'}
                              </span>
                              <div className="flex items-center gap-3 text-sm">
                                <span className="text-gray-400">{source.visitors} visits</span>
                                <span className="text-green-400">{source.signups} signups</span>
                                <span className={`px-2 py-0.5 rounded ${
                                  source.conversion_rate > 5
                                    ? 'bg-green-500/10 text-green-400'
                                    : 'bg-gray-700 text-gray-300'
                                }`}>
                                  {source.conversion_rate}%
                                </span>
                              </div>
                            </div>
                            <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
                              <div
                                className="h-full bg-[#f0b90b] rounded-full transition-all"
                                style={{
                                  width: `${(source.visitors / (analytics.total_visitors || 1)) * 100}%`
                                }}
                              />
                            </div>
                          </div>
                        </div>
                      ))}
                      {analytics.sources.length === 0 && (
                        <div className="text-center py-8 text-gray-500">
                          No visitor data yet. Share your tracking links!
                        </div>
                      )}
                    </div>
                    <div className="mt-4 pt-4 border-t border-gray-800">
                      <p className="text-xs text-gray-500 text-center">
                        Click on any source to view detailed user list
                      </p>
                    </div>
                  </div>

                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-4">Conversion Funnel</h3>
                    <div className="space-y-6">
                      <div>
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-gray-400">Visitors</span>
                          <span className="text-white font-medium">{analytics.total_visitors.toLocaleString()}</span>
                        </div>
                        <div className="h-10 bg-blue-500 rounded-lg flex items-center justify-center">
                          <span className="text-white font-bold">100%</span>
                        </div>
                      </div>

                      <div className="flex justify-center">
                        <div className="w-0 h-0 border-l-[20px] border-l-transparent border-r-[20px] border-r-transparent border-t-[15px] border-t-blue-500/50" />
                      </div>

                      <div>
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-gray-400">Signups</span>
                          <span className="text-white font-medium">{analytics.total_signups.toLocaleString()}</span>
                        </div>
                        <div
                          className="h-10 bg-green-500 rounded-lg flex items-center justify-center transition-all"
                          style={{ width: `${Math.max(analytics.overall_conversion_rate || 0, 10)}%` }}
                        >
                          <span className="text-white font-bold">{analytics.overall_conversion_rate || 0}%</span>
                        </div>
                      </div>
                    </div>

                    <div className="mt-6 p-4 bg-gray-800/50 rounded-lg">
                      <div className="text-sm text-gray-400 mb-2">Insight</div>
                      <div className="text-white">
                        {analytics.total_visitors > 0 && analytics.overall_conversion_rate < 5 ? (
                          <span>Your conversion rate is below average. Consider improving your landing page or targeting.</span>
                        ) : analytics.overall_conversion_rate >= 10 ? (
                          <span>Great conversion rate! Your traffic quality is excellent.</span>
                        ) : (
                          <span>Your conversion rate is average. Keep optimizing your funnel.</span>
                        )}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-4">Daily Visitors & Signups</h3>
                    <div className="space-y-2 max-h-64 overflow-y-auto">
                      {analytics.daily_stats.slice(-14).reverse().map((day, index) => (
                        <div key={index} className="flex items-center justify-between py-2 border-b border-gray-800/50">
                          <span className="text-gray-400">
                            {new Date(day.date).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                          </span>
                          <div className="flex items-center gap-4">
                            <span className="text-blue-400">{day.visitors} visits</span>
                            <span className="text-green-400">{day.signups} signups</span>
                            <span className="text-gray-500 text-sm">
                              {day.visitors > 0 ? ((day.signups / day.visitors) * 100).toFixed(1) : 0}%
                            </span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-4">Device Distribution</h3>
                    <div className="space-y-4">
                      {analytics.devices.map((device, index) => (
                        <div key={index} className="flex items-center gap-4">
                          <div className="w-10 h-10 bg-gray-800 rounded-lg flex items-center justify-center text-gray-400">
                            {getDeviceIcon(device.device)}
                          </div>
                          <div className="flex-1">
                            <div className="flex items-center justify-between mb-1">
                              <span className="text-white capitalize">{device.device || 'Unknown'}</span>
                              <div className="flex items-center gap-2 text-sm">
                                <span className="text-gray-400">{device.visitors} visits</span>
                                <span className="text-green-400">{device.signups} signups</span>
                              </div>
                            </div>
                            <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
                              <div
                                className="h-full bg-gradient-to-r from-[#f0b90b] to-[#d9a506] rounded-full"
                                style={{
                                  width: `${(device.visitors / (analytics.total_visitors || 1)) * 100}%`
                                }}
                              />
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'sources' && analytics && (
              <div className="space-y-4">
                <div className="bg-[#13141b] rounded-xl border border-gray-800 p-4">
                  <p className="text-sm text-gray-400">
                    Click on any source to view users who signed up from that source
                  </p>
                </div>
                <div className="bg-[#13141b] rounded-xl border border-gray-800 overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-800">
                          <th className="text-left p-4 text-gray-400 font-medium">Source</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Visitors</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Page Views</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Signups</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Conversion Rate</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {analytics.sources.map((row, index) => (
                          <tr key={index} className="border-b border-gray-800/50 hover:bg-gray-800/30 cursor-pointer" onClick={() => {
                            setSelectedSource(row.source || 'direct');
                            setActiveTab('visitors');
                          }}>
                            <td className="p-4">
                              <div className="flex items-center gap-2">
                                {getSourceIcon(row.source)}
                                <span className="text-white capitalize">{row.source}</span>
                              </div>
                            </td>
                            <td className="p-4 text-right text-white font-medium">{row.visitors.toLocaleString()}</td>
                            <td className="p-4 text-right text-gray-400">{row.page_views.toLocaleString()}</td>
                            <td className="p-4 text-right text-green-400">{row.signups}</td>
                            <td className="p-4 text-right">
                              <span className={`px-2 py-1 rounded text-sm ${
                                row.conversion_rate > 5
                                  ? 'bg-green-500/10 text-green-400'
                                  : 'bg-gray-700 text-gray-300'
                              }`}>
                                {row.conversion_rate}%
                              </span>
                            </td>
                            <td className="p-4 text-right">
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  setSelectedSource(row.source || 'direct');
                                  setActiveTab('visitors');
                                }}
                                className="flex items-center gap-1 px-3 py-1 bg-[#f0b90b]/10 hover:bg-[#f0b90b]/20 text-[#f0b90b] rounded text-sm transition-colors"
                              >
                                <Eye className="w-3 h-3" />
                                View Users
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {analytics.sources.length === 0 && (
                      <div className="text-center py-12 text-gray-500">
                        No source data available yet
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'campaigns' && analytics && (
              <div className="bg-[#13141b] rounded-xl border border-gray-800 overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-gray-800">
                        <th className="text-left p-4 text-gray-400 font-medium">Campaign</th>
                        <th className="text-left p-4 text-gray-400 font-medium">Source</th>
                        <th className="text-right p-4 text-gray-400 font-medium">Visitors</th>
                        <th className="text-right p-4 text-gray-400 font-medium">Signups</th>
                        <th className="text-right p-4 text-gray-400 font-medium">Conversion Rate</th>
                      </tr>
                    </thead>
                    <tbody>
                      {analytics.campaigns.map((row, index) => (
                        <tr key={index} className="border-b border-gray-800/50 hover:bg-gray-800/30">
                          <td className="p-4 text-white font-medium">{row.campaign}</td>
                          <td className="p-4">
                            <div className="flex items-center gap-2">
                              {getSourceIcon(row.source)}
                              <span className="text-gray-400 capitalize">{row.source}</span>
                            </div>
                          </td>
                          <td className="p-4 text-right text-white">{row.visitors.toLocaleString()}</td>
                          <td className="p-4 text-right text-green-400">{row.signups}</td>
                          <td className="p-4 text-right">
                            <span className={`px-2 py-1 rounded text-sm ${
                              row.conversion_rate > 5
                                ? 'bg-green-500/10 text-green-400'
                                : 'bg-gray-700 text-gray-300'
                            }`}>
                              {row.conversion_rate}%
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {analytics.campaigns.length === 0 && (
                    <div className="text-center py-12 text-gray-500">
                      No campaign data available. Create tracking links with campaigns!
                    </div>
                  )}
                </div>
              </div>
            )}

            {activeTab === 'links' && (
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  <h2 className="text-lg font-semibold text-white">Tracking Links</h2>
                  <button
                    onClick={() => setShowCreateLink(true)}
                    className="flex items-center gap-2 bg-[#f0b90b] hover:bg-[#d9a506] text-black px-4 py-2 rounded-lg font-medium transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                    Create Link
                  </button>
                </div>

                {showCreateLink && (
                  <div className="bg-[#13141b] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-4">Create Tracking Link</h3>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm text-gray-400 mb-1">Link Name *</label>
                        <input
                          type="text"
                          value={newLink.name}
                          onChange={(e) => setNewLink({ ...newLink, name: e.target.value })}
                          placeholder="e.g., TikTok Summer Campaign"
                          className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white"
                        />
                      </div>
                      <div>
                        <label className="block text-sm text-gray-400 mb-1">Source *</label>
                        <input
                          type="text"
                          value={newLink.utm_source}
                          onChange={(e) => setNewLink({ ...newLink, utm_source: e.target.value })}
                          placeholder="e.g., tiktok, facebook, instagram"
                          className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white"
                        />
                      </div>
                      <div>
                        <label className="block text-sm text-gray-400 mb-1">Medium</label>
                        <input
                          type="text"
                          value={newLink.utm_medium}
                          onChange={(e) => setNewLink({ ...newLink, utm_medium: e.target.value })}
                          placeholder="e.g., social, cpc, email"
                          className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white"
                        />
                      </div>
                      <div>
                        <label className="block text-sm text-gray-400 mb-1">Campaign</label>
                        <input
                          type="text"
                          value={newLink.utm_campaign}
                          onChange={(e) => setNewLink({ ...newLink, utm_campaign: e.target.value })}
                          placeholder="e.g., summer_promo_2024"
                          className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white"
                        />
                      </div>
                      <div>
                        <label className="block text-sm text-gray-400 mb-1">Content</label>
                        <input
                          type="text"
                          value={newLink.utm_content}
                          onChange={(e) => setNewLink({ ...newLink, utm_content: e.target.value })}
                          placeholder="e.g., video_ad_1"
                          className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white"
                        />
                      </div>
                      <div>
                        <label className="block text-sm text-gray-400 mb-1">Destination</label>
                        <input
                          type="text"
                          value={newLink.destination_url}
                          onChange={(e) => setNewLink({ ...newLink, destination_url: e.target.value })}
                          placeholder="/"
                          className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2 text-white"
                        />
                      </div>
                    </div>
                    <div className="flex justify-end gap-3 mt-4">
                      <button
                        onClick={() => setShowCreateLink(false)}
                        className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={createTrackingLink}
                        disabled={!newLink.name || !newLink.utm_source}
                        className="bg-[#f0b90b] hover:bg-[#d9a506] text-black px-6 py-2 rounded-lg font-medium transition-colors disabled:opacity-50"
                      >
                        Create
                      </button>
                    </div>
                  </div>
                )}

                <div className="bg-[#13141b] rounded-xl border border-gray-800 overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-800">
                          <th className="text-left p-4 text-gray-400 font-medium">Name</th>
                          <th className="text-left p-4 text-gray-400 font-medium">Source / Campaign</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Status</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {trackingLinks.map((link) => (
                          <tr key={link.id} className="border-b border-gray-800/50 hover:bg-gray-800/30">
                            <td className="p-4">
                              <div className="text-white font-medium">{link.name}</div>
                              <div className="text-xs text-gray-500 font-mono mt-1 max-w-xs truncate">
                                {getTrackingUrl(link)}
                              </div>
                            </td>
                            <td className="p-4">
                              <div className="flex items-center gap-2">
                                {getSourceIcon(link.utm_source)}
                                <div>
                                  <div className="text-gray-300 capitalize">{link.utm_source}</div>
                                  {link.utm_campaign && (
                                    <div className="text-xs text-gray-500">{link.utm_campaign}</div>
                                  )}
                                </div>
                              </div>
                            </td>
                            <td className="p-4 text-right">
                              <span className={`px-2 py-1 rounded text-xs ${
                                link.is_active
                                  ? 'bg-green-500/10 text-green-400'
                                  : 'bg-red-500/10 text-red-400'
                              }`}>
                                {link.is_active ? 'Active' : 'Inactive'}
                              </span>
                            </td>
                            <td className="p-4">
                              <div className="flex items-center justify-end gap-2">
                                <button
                                  onClick={() => copyTrackingUrl(link)}
                                  className={`p-2 rounded transition-colors ${
                                    copiedLink === link.id
                                      ? 'bg-green-500/20 text-green-400'
                                      : 'hover:bg-gray-700 text-gray-400'
                                  }`}
                                  title="Copy URL"
                                >
                                  {copiedLink === link.id ? (
                                    <span className="text-xs">Copied!</span>
                                  ) : (
                                    <Copy className="w-4 h-4" />
                                  )}
                                </button>
                                <button
                                  onClick={() => deleteTrackingLink(link.id)}
                                  className="p-2 hover:bg-red-500/10 rounded transition-colors"
                                  title="Delete"
                                >
                                  <Trash2 className="w-4 h-4 text-red-400" />
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {trackingLinks.length === 0 && (
                      <div className="text-center py-12 text-gray-500">
                        No tracking links created yet. Create one to start tracking!
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'visitors' && (
              <div className="space-y-4">
                {selectedSource && (
                  <div className="space-y-3">
                    <div className="bg-[#13141b] rounded-xl border border-gray-800 p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className="flex items-center gap-2">
                            {getSourceIcon(selectedSource)}
                            <span className="text-white font-medium">
                              Showing users from <span className="text-[#f0b90b] capitalize">{selectedSource}</span>
                            </span>
                          </div>
                          <span className="text-gray-400 text-sm">
                            ({filteredVisitors.length} {filteredVisitors.length === 1 ? 'visitor' : 'visitors'})
                          </span>
                        </div>
                        <button
                          onClick={() => setSelectedSource(null)}
                          className="flex items-center gap-2 px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg text-sm transition-colors"
                        >
                          <Trash2 className="w-3 h-3" />
                          Clear Filter
                        </button>
                      </div>
                    </div>

                    {filteredVisitors.length === 0 && visitors.length > 0 && (
                      <div className="bg-orange-500/10 border border-orange-500/20 rounded-xl p-4">
                        <p className="text-orange-400 text-sm mb-2">
                          No visitors found with source "{selectedSource}". Available sources in current data:
                        </p>
                        <div className="flex flex-wrap gap-2">
                          {Array.from(new Set(visitors.map(v => getVisitorSource(v)))).map((src, idx) => (
                            <button
                              key={idx}
                              onClick={() => setSelectedSource(src)}
                              className="px-2 py-1 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded text-xs transition-colors capitalize"
                            >
                              {src}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}

                <div className="flex items-center gap-4">
                  <div className="relative flex-1 max-w-md">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                    <input
                      type="text"
                      value={visitorSearch}
                      onChange={(e) => setVisitorSearch(e.target.value)}
                      placeholder="Search by email, name, source, or session..."
                      className="w-full bg-[#1a1d29] border border-gray-700 rounded-lg pl-10 pr-4 py-2.5 text-white"
                    />
                  </div>
                  <select
                    value={visitorFilter}
                    onChange={(e) => setVisitorFilter(e.target.value as any)}
                    className="bg-[#1a1d29] border border-gray-700 rounded-lg px-4 py-2.5 text-white"
                  >
                    <option value="all">All Visitors</option>
                    <option value="converted">Converted Only</option>
                    <option value="not_converted">Not Converted</option>
                  </select>
                </div>

                <div className="bg-[#13141b] rounded-xl border border-gray-800 overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-800">
                          <th className="text-left p-4 text-gray-400 font-medium">Visitor / User</th>
                          <th className="text-left p-4 text-gray-400 font-medium">Source</th>
                          <th className="text-left p-4 text-gray-400 font-medium">Campaign</th>
                          <th className="text-left p-4 text-gray-400 font-medium">Location</th>
                          <th className="text-left p-4 text-gray-400 font-medium">Device</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Pages</th>
                          <th className="text-left p-4 text-gray-400 font-medium">First Visit</th>
                          <th className="text-left p-4 text-gray-400 font-medium">Status</th>
                          <th className="text-right p-4 text-gray-400 font-medium">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filteredVisitors.map((visitor) => (
                          <tr key={visitor.id} className="border-b border-gray-800/50 hover:bg-gray-800/30">
                            <td className="p-4">
                              {visitor.converted && visitor.email ? (
                                <div>
                                  <div className="text-white font-medium">
                                    {visitor.full_name || 'Unknown'}
                                  </div>
                                  <div className="text-xs text-gray-500">
                                    {visitor.email}
                                  </div>
                                </div>
                              ) : (
                                <div>
                                  <div className="text-gray-400">Anonymous Visitor</div>
                                  <div className="text-xs text-gray-600 font-mono">
                                    {visitor.session_id.substring(0, 20)}...
                                  </div>
                                </div>
                              )}
                            </td>
                            <td className="p-4">
                              <div className="flex items-center gap-2">
                                {getSourceIcon(getVisitorSource(visitor))}
                                <span className="text-gray-300 capitalize">
                                  {visitor.utm_source || visitor.referrer_domain || 'Direct'}
                                </span>
                              </div>
                              {visitor.utm_medium && (
                                <div className="text-xs text-gray-500 mt-1">{visitor.utm_medium}</div>
                              )}
                            </td>
                            <td className="p-4 text-gray-400">{visitor.utm_campaign || '-'}</td>
                            <td className="p-4">
                              {visitor.city || visitor.country ? (
                                <div className="text-gray-300">
                                  <div>{visitor.city || '-'}</div>
                                  <div className="text-xs text-gray-500">{visitor.country || '-'}</div>
                                </div>
                              ) : (
                                <span className="text-gray-500">-</span>
                              )}
                            </td>
                            <td className="p-4">
                              <div className="flex items-center gap-2 text-gray-400">
                                {getDeviceIcon(visitor.device_type || '')}
                                <span className="capitalize">{visitor.device_type || 'Unknown'}</span>
                              </div>
                            </td>
                            <td className="p-4 text-right text-white">{visitor.page_views}</td>
                            <td className="p-4 text-gray-400">
                              {new Date(visitor.first_visit_at).toLocaleDateString()}
                              <div className="text-xs text-gray-600">
                                {new Date(visitor.first_visit_at).toLocaleTimeString()}
                              </div>
                            </td>
                            <td className="p-4">
                              {visitor.converted ? (
                                <span className="px-2 py-1 bg-green-500/10 text-green-400 rounded text-xs font-medium">
                                  Converted
                                </span>
                              ) : (
                                <span className="px-2 py-1 bg-gray-700 text-gray-400 rounded text-xs">
                                  Not Converted
                                </span>
                              )}
                            </td>
                            <td className="p-4 text-right">
                              {visitor.converted && visitor.user_id && (
                                <button
                                  onClick={() => navigateTo('adminuser', { userId: visitor.user_id })}
                                  className="p-2 hover:bg-gray-700 rounded transition-colors"
                                >
                                  <Eye className="w-4 h-4 text-gray-400" />
                                </button>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {filteredVisitors.length === 0 && (
                      <div className="text-center py-12 text-gray-500">
                        No visitors found matching your filters
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export default AdminAcquisition;
