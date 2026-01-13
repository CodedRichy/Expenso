import { ChevronRight } from 'lucide-react';
import { EmptyState } from './EmptyStates';

interface Group {
  id: string;
  name: string;
  status: string;
  amount: number;
  statusLine: string;
}

interface GroupsListProps {
  onSelectGroup: (group: Group) => void;
  onCreateGroup: () => void;
}

export function GroupsList({ onSelectGroup, onCreateGroup }: GroupsListProps) {
  const groups: Group[] = [
    {
      id: '1',
      name: 'Weekend Trip',
      status: 'closing',
      amount: 3240,
      statusLine: 'Cycle closes Sunday',
    },
    {
      id: '2',
      name: 'Movie Night',
      status: 'open',
      amount: 1850,
      statusLine: 'Cycle open until Sunday',
    },
    {
      id: '3',
      name: 'Office Lunch',
      status: 'settled',
      amount: 0,
      statusLine: 'All balances cleared',
    },
  ];

  if (groups.length === 0) {
    return <EmptyState type="no-groups" onAction={onCreateGroup} />;
  }

  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      {/* Header */}
      <div className="px-6 pt-16 pb-8">
        <h1 className="text-[34px] tracking-[-0.6px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
          Groups
        </h1>
      </div>

      {/* Groups List */}
      <div className="flex-1">
        {groups.map((group, index) => (
          <button
            key={group.id}
            onClick={() => onSelectGroup(group)}
            className="w-full px-6 flex items-center justify-between border-t border-[#E5E5E5] active:bg-[#EFEFEF] transition-colors"
            style={{ 
              borderTopWidth: index === 0 ? '1px' : '1px',
              paddingTop: group.status === 'settled' ? '18px' : '22px',
              paddingBottom: group.status === 'settled' ? '18px' : '22px',
              opacity: group.status === 'settled' ? 0.5 : 1
            }}
          >
            <div className="flex-1 text-left">
              <div 
                className="text-[19px] text-[#1A1A1A] mb-2" 
                style={{ 
                  fontWeight: group.status === 'closing' ? 600 : 500,
                  letterSpacing: '-0.3px'
                }}
              >
                {group.name}
              </div>
              {group.status !== 'settled' && (
                <div className="flex items-baseline gap-2">
                  <div 
                    className="text-[17px] text-[#1A1A1A]" 
                    style={{ fontWeight: 600 }}
                  >
                    ₹{group.amount.toLocaleString()}
                  </div>
                  <div className="text-[15px] text-[#6B6B6B]">
                    pending
                  </div>
                </div>
              )}
              {group.status === 'settled' && (
                <div className="text-[15px] text-[#9B9B9B]">
                  All balances cleared
                </div>
              )}
              {group.status !== 'settled' && (
                <div 
                  className="text-[15px] mt-1.5"
                  style={{ 
                    color: group.status === 'closing' ? '#1A1A1A' : '#6B6B6B',
                    fontWeight: group.status === 'closing' ? 500 : 400
                  }}
                >
                  {group.statusLine}
                </div>
              )}
            </div>
            <ChevronRight className="w-5 h-5 text-[#B0B0B0] ml-4 flex-shrink-0" />
          </button>
        ))}
      </div>

      {/* Create Group Button */}
      <div className="px-6 py-6 border-t border-[#E5E5E5]">
        <button 
          onClick={onCreateGroup}
          className="w-full py-3 text-[17px] text-[#5B7C99]" 
          style={{ fontWeight: 500 }}
        >
          Create Group
        </button>
      </div>
    </div>
  );
}