export type Gender = 'male' | 'female' | 'non-binary' | 'other';
export type DatingIntention = 'casual' | 'dating' | 'coffee' | 'serious' | 'friendship' | 'travel';
export type VerificationStatus = 'unverified' | 'pending' | 'verified' | 'rejected';
export type SubscriptionTier = 'free' | 'vip_weekly' | 'vip_monthly' | 'vip_3month' | 'vip_annual';

export interface UserLocation {
  latitude: number;
  longitude: number;
  city: string;
  country: string;
  isPassportActive: boolean; // VIP Passport feature
}

export interface UserProfile {
  id: string;
  userId: string;
  displayName: string;
  age: number;
  birthDate: string;
  gender: Gender;
  interestedIn: Gender[];
  bio: string;
  photos: string[]; // List of secure image URLs
  interests: string[];
  datingIntention: DatingIntention;
  occupation?: string;
  education?: string;
  homeDistrict?: string; // Sri Lanka district (e.g., Colombo, Kandy, Galle, Jaffna)
  location: UserLocation;
  isStealthMode: boolean; // VIP: only visible to people user swiped right on
  verificationStatus: VerificationStatus;
  verificationSelfieUrl?: string;
  boostedUntil?: string | null;
  lastActive: string;
  createdAt: string;
}

export type StaffRole = 'super_admin' | 'admin' | 'moderator' | 'finance' | 'support';

export interface StaffMember {
  id: string;
  name: string;
  phone: string;
  username: string;
  role: StaffRole;
  password?: string;
  createdAt: string;
  isActive: boolean;
}

export interface User {
  id: string;
  phone: string;
  email?: string;
  passwordHash?: string;
  role: 'user' | 'admin' | 'moderator' | 'finance' | 'support';
  isBanned: boolean;
  isDeleted: boolean;
  subscriptionTier: SubscriptionTier;
  subscriptionExpiresAt?: string | null;
  dailySwipeCount: number;
  lastSwipeReset: string;
  superLikesRemaining: number;
  freeTrialUsed: boolean;
  blockedUserIds: string[];
  createdAt: string;
  updatedAt: string;
}

export type SwipeAction = 'left' | 'right' | 'superlike';

export interface Swipe {
  id: string;
  fromUserId: string;
  toUserId: string;
  action: SwipeAction;
  superLikeMessage?: string;
  createdAt: string;
}

export interface Match {
  id: string;
  user1Id: string;
  user2Id: string;
  lastMessageAt?: string;
  createdAt: string;
  isActive: boolean;
}

export interface Message {
  id: string;
  matchId: string;
  senderId: string;
  receiverId: string;
  content: string;
  mediaUrl?: string;
  isBlurred: boolean; // Privacy photo blur feature
  isVoiceNote: boolean;
  isRead: boolean;
  createdAt: string;
}

export interface Report {
  id: string;
  reporterId: string;
  reportedUserId: string;
  reason: 'inappropriate_photos' | 'fake_profile' | 'harassment' | 'spam' | 'underage' | 'other';
  description?: string;
  evidencePhotoUrl?: string;
  createdAt: string;
}

export interface PaymentTransaction {
  id: string;
  userId: string;
  orderId: string;
  amount: number;
  currency: 'LKR' | 'USD';
  tier: SubscriptionTier;
  provider: 'payhere' | 'apple_iap' | 'google_play' | 'bank_transfer';
  status: 'pending' | 'success' | 'failed' | 'cancelled';
  payherePaymentId?: string;
  bankName?: string;
  referenceCode?: string;
  slipNote?: string;
  createdAt: string;
}

export interface DateRating {
  id: string;
  fromUserId: string;
  toUserId: string;
  stars: number; // 1 to 5
  tags: string[]; // e.g. ['Great conversation', 'Polite & Respectful', 'Looks like photos', 'Punctual', 'Felt 100% Safe']
  review?: string;
  createdAt: string;
}
