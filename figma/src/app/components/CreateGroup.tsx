import { ChevronLeft } from 'lucide-react';
import { useState } from 'react';

interface CreateGroupProps {
  onBack: () => void;
  onCreate: (groupData: {
    name: string;
    rhythm: 'weekly' | 'monthly' | 'trip';
    settlementDay?: number;
  }) => void;
}

export function CreateGroup({ onBack, onCreate }: CreateGroupProps) {
  const [name, setName] = useState('');
  const [rhythm, setRhythm] = useState<'weekly' | 'monthly' | 'trip'>('weekly');
  const [settlementDay, setSettlementDay] = useState<number>(0); // 0 = Sunday

  const getPreviewText = () => {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (rhythm === 'weekly') {
      return `This group settles every ${days[settlementDay]}.`;
    }
    if (rhythm === 'monthly') {
      return `This group settles on the ${settlementDay + 1}${getOrdinalSuffix(settlementDay + 1)} of each month.`;
    }
    return 'This group settles when the trip ends.';
  };

  const getOrdinalSuffix = (day: number) => {
    if (day > 3 && day < 21) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  };

  const handleCreate = () => {
    if (name.trim()) {
      onCreate({
        name: name.trim(),
        rhythm,
        settlementDay: rhythm === 'trip' ? undefined : settlementDay,
      });
    }
  };

  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      {/* Header */}
      <div className="px-6 pt-16 pb-6">
        <button
          onClick={onBack}
          className="mb-5 -ml-2 p-2 active:opacity-60 transition-opacity"
        >
          <ChevronLeft className="w-6 h-6 text-[#1A1A1A]" />
        </button>
        <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
          Create Group
        </h1>
      </div>

      {/* Form */}
      <div className="flex-1 px-6">
        {/* Group Name */}
        <div className="mb-8">
          <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
            Group Name
          </div>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Weekend Trip"
            autoFocus
            className="w-full py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors"
            style={{ borderRadius: '8px' }}
          />
        </div>

        {/* Settlement Rhythm */}
        <div className="mb-8">
          <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
            Settlement Rhythm
          </div>
          <div className="flex flex-col gap-0">
            {['weekly', 'monthly', 'trip'].map((option, index) => (
              <button
                key={option}
                onClick={() => setRhythm(option as 'weekly' | 'monthly' | 'trip')}
                className="py-4 px-5 flex items-center justify-between border-t border-[#E5E5E5] bg-white active:bg-[#EFEFEF] transition-colors"
                style={{
                  borderTopWidth: index === 0 ? '1px' : '1px',
                  borderBottomWidth: index === 2 ? '1px' : '0',
                  borderTopLeftRadius: index === 0 ? '8px' : '0',
                  borderTopRightRadius: index === 0 ? '8px' : '0',
                  borderBottomLeftRadius: index === 2 ? '8px' : '0',
                  borderBottomRightRadius: index === 2 ? '8px' : '0',
                }}
              >
                <span className="text-[17px] text-[#1A1A1A] capitalize">
                  {option === 'trip' ? 'Trip-based' : option}
                </span>
                <div
                  className="w-5 h-5 border-2 rounded-full flex items-center justify-center"
                  style={{
                    borderColor: rhythm === option ? '#1A1A1A' : '#D0D0D0',
                  }}
                >
                  {rhythm === option && (
                    <div className="w-2.5 h-2.5 rounded-full bg-[#1A1A1A]" />
                  )}
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Settlement Day */}
        {rhythm !== 'trip' && (
          <div className="mb-8">
            <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
              {rhythm === 'weekly' ? 'Settlement Day' : 'Settlement Date'}
            </div>
            <select
              value={settlementDay}
              onChange={(e) => setSettlementDay(Number(e.target.value))}
              className="w-full py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] outline-none focus:border-[#1A1A1A] transition-colors"
              style={{ borderRadius: '8px' }}
            >
              {rhythm === 'weekly' ? (
                ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'].map((day, i) => (
                  <option key={i} value={i}>{day}</option>
                ))
              ) : (
                Array.from({ length: 28 }, (_, i) => i + 1).map((day) => (
                  <option key={day} value={day - 1}>{day}{getOrdinalSuffix(day)}</option>
                ))
              )}
            </select>
          </div>
        )}

        {/* Preview */}
        <div className="p-4 bg-white border border-[#E5E5E5]" style={{ borderRadius: '8px' }}>
          <div className="text-[15px] text-[#6B6B6B]">
            {getPreviewText()}
          </div>
        </div>
      </div>

      {/* Create Button */}
      <div className="px-6 py-5 border-t border-[#E5E5E5]">
        <button
          onClick={handleCreate}
          disabled={!name.trim()}
          className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] disabled:bg-[#E5E5E5] disabled:text-[#B0B0B0] transition-colors"
          style={{ fontWeight: 500, borderRadius: '8px' }}
        >
          Create Group
        </button>
      </div>
    </div>
  );
}
