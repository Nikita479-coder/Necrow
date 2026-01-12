import { useState, useMemo } from 'react';
import { Info, Calendar } from 'lucide-react';

interface DepositData {
  created_at: string;
  status: string;
  price_amount: number;
  actually_paid: number | null;
  outcome_amount: number | null;
}

interface Props {
  deposits: DepositData[];
}

type TimeRange = '7D' | '1M' | '3M';
type ViewMode = 'amount' | 'count';

export default function DepositStatisticsChart({ deposits }: Props) {
  const [timeRange, setTimeRange] = useState<TimeRange>('7D');
  const [viewMode, setViewMode] = useState<ViewMode>('amount');

  const chartData = useMemo(() => {
    const now = new Date();
    let daysToShow = 7;
    if (timeRange === '1M') daysToShow = 30;
    if (timeRange === '3M') daysToShow = 90;

    const dayData: Record<string, { attempts: number; successful: number; attemptAmount: number; successfulAmount: number }> = {};

    for (let i = daysToShow - 1; i >= 0; i--) {
      const date = new Date(now);
      date.setDate(date.getDate() - i);
      const dateKey = date.toISOString().split('T')[0];
      dayData[dateKey] = { attempts: 0, successful: 0, attemptAmount: 0, successfulAmount: 0 };
    }

    deposits.forEach(deposit => {
      const depositDate = new Date(deposit.created_at).toISOString().split('T')[0];
      if (dayData[depositDate]) {
        dayData[depositDate].attempts += 1;
        dayData[depositDate].attemptAmount += deposit.price_amount || 0;

        const successfulStatuses = ['finished', 'completed', 'partially_paid', 'overpaid'];
        if (successfulStatuses.includes(deposit.status)) {
          dayData[depositDate].successful += 1;
          const amount = deposit.actually_paid || deposit.outcome_amount || deposit.price_amount || 0;
          dayData[depositDate].successfulAmount += parseFloat(amount.toString());
        }
      }
    });

    return Object.entries(dayData).map(([date, data]) => ({
      date,
      displayDate: formatDisplayDate(date, daysToShow),
      ...data
    }));
  }, [deposits, timeRange]);

  function formatDisplayDate(dateStr: string, daysToShow: number) {
    const date = new Date(dateStr);
    if (daysToShow <= 7) {
      return date.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric' });
    } else if (daysToShow <= 30) {
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    } else {
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
  }

  const maxValue = useMemo(() => {
    if (viewMode === 'amount') {
      return Math.max(...chartData.map(d => Math.max(d.attemptAmount, d.successfulAmount)), 100);
    }
    return Math.max(...chartData.map(d => Math.max(d.attempts, d.successful)), 1);
  }, [chartData, viewMode]);

  const chartHeight = 200;
  const chartWidth = 100;
  const padding = { top: 20, right: 10, bottom: 30, left: 15 };

  const getYLabels = () => {
    const steps = 4;
    const labels = [];
    for (let i = steps; i >= 0; i--) {
      const value = (maxValue / steps) * i;
      if (viewMode === 'amount') {
        if (value >= 1000) {
          labels.push(`$${(value / 1000).toFixed(0)}k`);
        } else {
          labels.push(`$${value.toFixed(0)}`);
        }
      } else {
        labels.push(value.toFixed(0));
      }
    }
    return labels;
  };

  const generatePath = (dataKey: 'attemptAmount' | 'successfulAmount' | 'attempts' | 'successful') => {
    const effectiveWidth = chartWidth - padding.left - padding.right;
    const effectiveHeight = chartHeight - padding.top - padding.bottom;
    const xStep = effectiveWidth / Math.max(chartData.length - 1, 1);

    const points = chartData.map((d, i) => {
      const x = padding.left + i * xStep;
      const value = viewMode === 'amount'
        ? (dataKey === 'attemptAmount' ? d.attemptAmount : d.successfulAmount)
        : (dataKey === 'attempts' ? d.attempts : d.successful);
      const y = padding.top + effectiveHeight - (value / maxValue) * effectiveHeight;
      return { x, y };
    });

    if (points.length === 0) return '';

    let path = `M ${points[0].x} ${points[0].y}`;
    for (let i = 1; i < points.length; i++) {
      const prev = points[i - 1];
      const curr = points[i];
      const cpx1 = prev.x + (curr.x - prev.x) / 3;
      const cpx2 = prev.x + (2 * (curr.x - prev.x)) / 3;
      path += ` C ${cpx1} ${prev.y}, ${cpx2} ${curr.y}, ${curr.x} ${curr.y}`;
    }

    return path;
  };

  const generateAreaPath = (dataKey: 'attemptAmount' | 'successfulAmount' | 'attempts' | 'successful') => {
    const linePath = generatePath(dataKey);
    if (!linePath) return '';

    const effectiveWidth = chartWidth - padding.left - padding.right;
    const effectiveHeight = chartHeight - padding.top - padding.bottom;
    const xStep = effectiveWidth / Math.max(chartData.length - 1, 1);

    const lastX = padding.left + (chartData.length - 1) * xStep;
    const firstX = padding.left;
    const bottomY = padding.top + effectiveHeight;

    return `${linePath} L ${lastX} ${bottomY} L ${firstX} ${bottomY} Z`;
  };

  const totalAttempts = chartData.reduce((sum, d) => sum + d.attempts, 0);
  const totalSuccessful = chartData.reduce((sum, d) => sum + d.successful, 0);
  const totalAttemptAmount = chartData.reduce((sum, d) => sum + d.attemptAmount, 0);
  const totalSuccessfulAmount = chartData.reduce((sum, d) => sum + d.successfulAmount, 0);
  const successRate = totalAttempts > 0 ? ((totalSuccessful / totalAttempts) * 100).toFixed(1) : '0';

  const yLabels = getYLabels();

  return (
    <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 mb-8">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <h3 className="text-lg font-semibold text-white">Statistics</h3>
          <div className="relative group">
            <Info className="w-4 h-4 text-gray-500 cursor-help" />
            <div className="absolute left-0 top-6 w-64 bg-[#2a2d35] rounded-lg p-3 text-xs text-gray-300 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10 shadow-xl border border-gray-700">
              <p className="mb-2"><span className="text-blue-400">Blue line:</span> Deposit attempts</p>
              <p><span className="text-green-400">Green line:</span> Successful deposits</p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex bg-[#0b0e11] rounded-lg p-1 border border-gray-700">
            <button
              onClick={() => setViewMode('amount')}
              className={`px-3 py-1.5 text-xs font-medium rounded-md transition-all ${
                viewMode === 'amount'
                  ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              Amount
            </button>
            <button
              onClick={() => setViewMode('count')}
              className={`px-3 py-1.5 text-xs font-medium rounded-md transition-all ${
                viewMode === 'count'
                  ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              Count
            </button>
          </div>

          <div className="flex bg-[#0b0e11] rounded-lg p-1 border border-gray-700">
            {(['7D', '1M', '3M'] as TimeRange[]).map(range => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={`px-3 py-1.5 text-xs font-medium rounded-md transition-all ${
                  timeRange === range
                    ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                {range}
              </button>
            ))}
            <button className="px-2 py-1.5 text-gray-400 hover:text-white transition-colors">
              <Calendar className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className="bg-[#0b0e11] rounded-lg p-3 border border-gray-800">
          <p className="text-xs text-gray-500 mb-1">Total Attempts</p>
          <p className="text-lg font-bold text-white">{totalAttempts}</p>
        </div>
        <div className="bg-[#0b0e11] rounded-lg p-3 border border-gray-800">
          <p className="text-xs text-gray-500 mb-1">Successful</p>
          <p className="text-lg font-bold text-green-400">{totalSuccessful}</p>
        </div>
        <div className="bg-[#0b0e11] rounded-lg p-3 border border-gray-800">
          <p className="text-xs text-gray-500 mb-1">Total Volume</p>
          <p className="text-lg font-bold text-white">${totalSuccessfulAmount.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
        </div>
        <div className="bg-[#0b0e11] rounded-lg p-3 border border-gray-800">
          <p className="text-xs text-gray-500 mb-1">Success Rate</p>
          <p className="text-lg font-bold text-blue-400">{successRate}%</p>
        </div>
      </div>

      <div className="relative">
        <div className="absolute left-0 top-0 bottom-8 w-12 flex flex-col justify-between text-xs text-gray-500">
          {yLabels.map((label, i) => (
            <span key={i} className="text-right pr-2">{label}</span>
          ))}
        </div>

        <div className="ml-12">
          <svg
            viewBox={`0 0 ${chartWidth} ${chartHeight}`}
            preserveAspectRatio="none"
            className="w-full h-48"
          >
            <defs>
              <linearGradient id="attemptsGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.3" />
                <stop offset="100%" stopColor="#3b82f6" stopOpacity="0" />
              </linearGradient>
              <linearGradient id="successfulGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#22c55e" stopOpacity="0.3" />
                <stop offset="100%" stopColor="#22c55e" stopOpacity="0" />
              </linearGradient>
            </defs>

            {[0, 1, 2, 3, 4].map(i => {
              const y = padding.top + ((chartHeight - padding.top - padding.bottom) / 4) * i;
              return (
                <line
                  key={i}
                  x1={padding.left}
                  y1={y}
                  x2={chartWidth - padding.right}
                  y2={y}
                  stroke="#374151"
                  strokeWidth="0.5"
                  strokeDasharray="2,2"
                />
              );
            })}

            <path
              d={generateAreaPath(viewMode === 'amount' ? 'attemptAmount' : 'attempts')}
              fill="url(#attemptsGradient)"
            />

            <path
              d={generatePath(viewMode === 'amount' ? 'attemptAmount' : 'attempts')}
              fill="none"
              stroke="#3b82f6"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />

            <path
              d={generateAreaPath(viewMode === 'amount' ? 'successfulAmount' : 'successful')}
              fill="url(#successfulGradient)"
            />

            <path
              d={generatePath(viewMode === 'amount' ? 'successfulAmount' : 'successful')}
              fill="none"
              stroke="#22c55e"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>

          <div className="flex justify-between text-xs text-gray-500 mt-2 px-2">
            {chartData.filter((_, i) => {
              const step = Math.ceil(chartData.length / 7);
              return i % step === 0 || i === chartData.length - 1;
            }).map((d, i) => (
              <span key={i}>{d.displayDate}</span>
            ))}
          </div>
        </div>
      </div>

      <div className="flex items-center justify-center gap-6 mt-4 pt-4 border-t border-gray-800">
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full bg-blue-500"></div>
          <span className="text-xs text-gray-400">Attempts</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full bg-green-500"></div>
          <span className="text-xs text-gray-400">Successful</span>
        </div>
      </div>
    </div>
  );
}
