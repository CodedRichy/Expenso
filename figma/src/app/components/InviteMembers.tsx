import { ChevronLeft, Link as LinkIcon, Copy, Check } from 'lucide-react';
import { useState } from 'react';

interface Member {
  id: string;
  phone: string;
  status: 'invited' | 'joined';
}

interface InviteMembersProps {
  groupName: string;
  onBack: () => void;
  onComplete: () => void;
}

export function InviteMembers({ groupName, onBack, onComplete }: InviteMembersProps) {
  const [phone, setPhone] = useState('');
  const [linkCopied, setLinkCopied] = useState(false);
  const [members, setMembers] = useState<Member[]>([
    { id: '1', phone: '+91 98765 43210', status: 'joined' },
    { id: '2', phone: '+91 87654 32109', status: 'invited' },
  ]);

  const handleCopyLink = () => {
    setLinkCopied(true);
    setTimeout(() => setLinkCopied(false), 2000);
  };

  const handleAddMember = () => {
    if (phone.length === 10) {
      setMembers([
        ...members,
        {
          id: Date.now().toString(),
          phone: `+91 ${phone.slice(0, 5)} ${phone.slice(5)}`,
          status: 'invited',
        },
      ]);
      setPhone('');
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
        <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A] mb-1" style={{ fontWeight: 600 }}>
          {groupName}
        </h1>
        <div className="text-[17px] text-[#6B6B6B]">
          Invite members
        </div>
      </div>

      {/* Invite Link */}
      <div className="px-6 pb-6">
        <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
          Share Link
        </div>
        <button
          onClick={handleCopyLink}
          className="w-full py-4 px-4 bg-white border border-[#E5E5E5] flex items-center justify-between active:bg-[#EFEFEF] transition-colors"
          style={{ borderRadius: '8px' }}
        >
          <div className="flex items-center gap-3">
            <LinkIcon className="w-5 h-5 text-[#6B6B6B]" />
            <span className="text-[17px] text-[#1A1A1A]">
              {linkCopied ? 'Link copied' : 'Copy invite link'}
            </span>
          </div>
          {linkCopied ? (
            <Check className="w-5 h-5 text-[#1A1A1A]" />
          ) : (
            <Copy className="w-5 h-5 text-[#6B6B6B]" />
          )}
        </button>
      </div>

      {/* Add by Phone */}
      <div className="px-6 pb-6">
        <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
          Add by Phone
        </div>
        <div className="flex gap-2">
          <div className="px-4 py-4 bg-white border border-[#E5E5E5] text-[17px] text-[#6B6B6B]" style={{ borderRadius: '8px' }}>
            +91
          </div>
          <input
            type="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
            onKeyDown={(e) => e.key === 'Enter' && handleAddMember()}
            placeholder="Phone number"
            className="flex-1 py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors"
            style={{ borderRadius: '8px' }}
          />
          <button
            onClick={handleAddMember}
            disabled={phone.length !== 10}
            className="px-5 py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] disabled:bg-[#E5E5E5] disabled:text-[#B0B0B0] transition-colors"
            style={{ fontWeight: 500, borderRadius: '8px' }}
          >
            Add
          </button>
        </div>
      </div>

      {/* Members List */}
      <div className="flex-1 border-t border-[#E5E5E5]">
        <div className="px-6 py-4 text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B]" style={{ fontWeight: 500 }}>
          Members
        </div>
        {members.map((member, index) => (
          <div
            key={member.id}
            className="px-6 py-4 flex items-center justify-between border-t border-[#E5E5E5]"
            style={{ borderTopWidth: index === 0 ? '0' : '1px' }}
          >
            <div className="text-[17px] text-[#1A1A1A]">
              {member.phone}
            </div>
            <div
              className="text-[15px]"
              style={{
                color: member.status === 'joined' ? '#1A1A1A' : '#6B6B6B',
                fontWeight: member.status === 'joined' ? 500 : 400,
              }}
            >
              {member.status === 'joined' ? 'Joined' : 'Invited'}
            </div>
          </div>
        ))}
      </div>

      {/* Done Button */}
      <div className="px-6 py-5 border-t border-[#E5E5E5]">
        <button
          onClick={onComplete}
          className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
          style={{ fontWeight: 500, borderRadius: '8px' }}
        >
          Done
        </button>
      </div>
    </div>
  );
}
