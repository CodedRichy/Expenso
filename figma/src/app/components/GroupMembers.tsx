import { ChevronLeft } from 'lucide-react';

interface Member {
  id: string;
  phone: string;
  status: 'joined' | 'invited';
}

interface GroupMembersProps {
  groupName: string;
  members: Member[];
  onBack: () => void;
}

export function GroupMembers({ groupName, members, onBack }: GroupMembersProps) {
  const joinedMembers = members.filter((m) => m.status === 'joined');
  const invitedMembers = members.filter((m) => m.status === 'invited');

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
        <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A] mb-1" style={{ fontWeight: 600 }}>
          {groupName}
        </h1>
        <div className="text-[17px] text-[#6B6B6B]">
          {joinedMembers.length} member{joinedMembers.length !== 1 ? 's' : ''}
        </div>
      </div>

      {/* Joined Members */}
      {joinedMembers.length > 0 && (
        <div className="mb-6">
          <div className="px-6 py-4 text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B]" style={{ fontWeight: 500 }}>
            Active
          </div>
          {joinedMembers.map((member, index) => (
            <div
              key={member.id}
              className="px-6 py-4 flex items-center justify-between border-t border-[#E5E5E5]"
              style={{ borderTopWidth: index === 0 ? '0' : '1px' }}
            >
              <div className="text-[17px] text-[#1A1A1A]">
                {member.phone}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Invited Members */}
      {invitedMembers.length > 0 && (
        <div>
          <div className="px-6 py-4 text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B]" style={{ fontWeight: 500 }}>
            Pending
          </div>
          {invitedMembers.map((member, index) => (
            <div
              key={member.id}
              className="px-6 py-4 flex items-center justify-between border-t border-[#E5E5E5]"
              style={{ borderTopWidth: index === 0 ? '0' : '1px' }}
            >
              <div className="text-[17px] text-[#6B6B6B]">
                {member.phone}
              </div>
              <div className="text-[15px] text-[#6B6B6B]">
                Invited
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
