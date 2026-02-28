import { useEffect, useState } from 'react';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';
import Navbar from '../components/Navbar';
import { ArrowLeft, Calendar, Trophy, Target, AlertCircle, CheckCircle } from 'lucide-react';

interface Event {
  id: string;
  slug: string;
  title: string;
  subtitle: string;
  description: string;
  event_type: string;
  start_date?: string;
  end_date?: string;
  prize_pool: number;
  requirements: any;
  rules: string[];
  prizes: any[];
  disqualifications: string[];
  how_to_participate: string[];
  metadata: any;
}

export default function EventDetails() {
  const { navigateTo, navigationState } = useNavigation();
  const [event, setEvent] = useState<Event | null>(null);
  const [loading, setLoading] = useState(true);
  const slug = navigationState?.slug;

  useEffect(() => {
    if (slug) {
      loadEvent();
    }
  }, [slug]);

  const loadEvent = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('promotional_events')
        .select('*')
        .eq('slug', slug)
        .eq('is_active', true)
        .maybeSingle();

      if (error) throw error;
      setEvent(data);
    } catch (error) {
      console.error('Error loading event:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-slate-400">Loading event details...</div>
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800">
        <Navbar />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-white mb-4">Event Not Found</h2>
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

      <div className="max-w-6xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('home')}
          className="flex items-center gap-2 text-slate-400 hover:text-white mb-6 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>

        <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 overflow-hidden">
          <div className="bg-gradient-to-r from-blue-600 to-purple-600 p-8 text-white">
            <div className="flex items-start justify-between">
              <div>
                <h1 className="text-4xl font-bold mb-2">{event.title}</h1>
                {event.subtitle && (
                  <p className="text-xl text-blue-100">{event.subtitle}</p>
                )}
              </div>
              <div className="bg-white/20 backdrop-blur-sm rounded-lg px-4 py-2">
                <div className="text-sm text-blue-100">Prize Pool</div>
                <div className="text-2xl font-bold">${event.prize_pool.toLocaleString()}</div>
              </div>
            </div>
            <p className="mt-4 text-blue-50 text-lg">{event.description}</p>
          </div>

          <div className="p-8 space-y-8">
            {event.start_date && event.end_date && (
              <div className="flex items-center gap-3 p-4 bg-slate-700/50 rounded-lg">
                <Calendar className="w-5 h-5 text-blue-400" />
                <div>
                  <div className="text-sm text-slate-400">Event Period</div>
                  <div className="text-white font-medium">
                    {new Date(event.start_date).toLocaleDateString()} - {new Date(event.end_date).toLocaleDateString()}
                  </div>
                </div>
              </div>
            )}

            {event.requirements && (
              <div>
                <div className="flex items-center gap-2 mb-4">
                  <Target className="w-5 h-5 text-green-400" />
                  <h2 className="text-2xl font-bold text-white">Requirements</h2>
                </div>
                <div className="bg-slate-700/30 rounded-lg p-6 space-y-3">
                  {Object.entries(event.requirements).map(([key, value]) => (
                    <div key={key} className="flex items-start gap-3">
                      <CheckCircle className="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" />
                      <div>
                        <span className="text-slate-400 capitalize">{key.replace(/_/g, ' ')}: </span>
                        <span className="text-white font-medium">{String(value)}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {event.prizes && event.prizes.length > 0 && (
              <div>
                <div className="flex items-center gap-2 mb-4">
                  <Trophy className="w-5 h-5 text-yellow-400" />
                  <h2 className="text-2xl font-bold text-white">Prizes</h2>
                </div>
                <div className="grid gap-3">
                  {event.prizes.map((prize, index) => (
                    <div
                      key={index}
                      className="flex items-center justify-between p-4 bg-gradient-to-r from-yellow-900/20 to-yellow-800/20 rounded-lg border border-yellow-700/30"
                    >
                      <div className="flex items-center gap-3">
                        {prize.rank && (
                          <div className="w-10 h-10 rounded-full bg-yellow-600 flex items-center justify-center text-white font-bold">
                            {prize.rank}
                          </div>
                        )}
                        <span className="text-slate-300">{prize.description || prize.type || `Rank ${prize.rank}`}</span>
                      </div>
                      <div className="text-2xl font-bold text-yellow-400">
                        {prize.prize_each ? `${prize.prize_each} ${prize.currency} × ${prize.winners}` : `${prize.prize} ${prize.currency}`}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {event.rules && event.rules.length > 0 && (
              <div>
                <h2 className="text-2xl font-bold text-white mb-4">Rules</h2>
                <div className="bg-slate-700/30 rounded-lg p-6 space-y-3">
                  {event.rules.map((rule, index) => (
                    <div key={index} className="flex items-start gap-3">
                      <div className="w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center text-white text-sm flex-shrink-0">
                        {index + 1}
                      </div>
                      <p className="text-slate-300">{rule}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {event.how_to_participate && event.how_to_participate.length > 0 && (
              <div>
                <h2 className="text-2xl font-bold text-white mb-4">How to Participate</h2>
                <div className="bg-blue-900/20 rounded-lg p-6 space-y-3 border border-blue-700/30">
                  {event.how_to_participate.map((step, index) => (
                    <div key={index} className="flex items-start gap-3">
                      <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-white font-bold flex-shrink-0">
                        {index + 1}
                      </div>
                      <p className="text-slate-300 pt-1">{step}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {event.disqualifications && event.disqualifications.length > 0 && (
              <div>
                <div className="flex items-center gap-2 mb-4">
                  <AlertCircle className="w-5 h-5 text-red-400" />
                  <h2 className="text-2xl font-bold text-white">Disqualification Conditions</h2>
                </div>
                <div className="bg-red-900/20 rounded-lg p-6 space-y-3 border border-red-700/30">
                  {event.disqualifications.map((condition, index) => (
                    <div key={index} className="flex items-start gap-3">
                      <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                      <p className="text-slate-300">{condition}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="flex gap-4 pt-4">
              <button
                onClick={() => navigateTo('home')}
                className="flex-1 py-3 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg font-medium hover:from-blue-500 hover:to-purple-500 transition-all"
              >
                Contact Support to Enter
              </button>
              <button
                onClick={() => navigateTo('terms', { slug: `${slug}-challenge` })}
                className="px-6 py-3 bg-slate-700 text-white rounded-lg font-medium hover:bg-slate-600 transition-colors"
              >
                View Full Terms
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
