import { v4 as uuidv4 } from 'uuid';
import {
  User,
  UserProfile,
  Swipe,
  Match,
  Message,
  Report,
  PaymentTransaction,
  DateRating,
  SwipeAction,
  SubscriptionTier,
  StaffMember,
  StaffRole,
} from '../models/types';
import { calculateDistanceKm } from '../utils/geo';
import { logger } from '../utils/logger';
import fs from 'fs';
import path from 'path';

// Hybrid In-Memory Data Store with Auto-Sync Disk Persistence & Zero-Injection Architecture
// Ready for PostgreSQL/MongoDB persistence via Prisma/Mongoose interfaces

class DataStore {
  public users: Map<string, User> = new Map();
  public profiles: Map<string, UserProfile> = new Map(); // Keyed by userId
  public swipes: Swipe[] = []; // In production: Redis SET + Postgres swipe table
  public matches: Map<string, Match> = new Map();
  public messages: Message[] = [];
  public reports: Report[] = [];
  public payments: Map<string, PaymentTransaction> = new Map();
  public dateRatings: DateRating[] = [];
  public activeRefreshTokens: Set<string> = new Set();
  public demoUserIds: Set<string> = new Set();
  public staffMembers: Map<string, StaffMember> = new Map();

  private dataFilePath = path.join(__dirname, '../../data/store.json');
  private saveTimer: NodeJS.Timeout | null = null;

  constructor() {
    this.initPersistence();
  }

  private initPersistence(): void {
    try {
      const dataDir = path.dirname(this.dataFilePath);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }

      if (fs.existsSync(this.dataFilePath)) {
        const raw = fs.readFileSync(this.dataFilePath, 'utf-8');
        const parsed = JSON.parse(raw);

        if (parsed.users && Array.isArray(parsed.users)) {
          this.users = new Map(parsed.users);
        }
        if (parsed.profiles && Array.isArray(parsed.profiles)) {
          this.profiles = new Map(parsed.profiles);
        }
        if (parsed.matches && Array.isArray(parsed.matches)) {
          this.matches = new Map(parsed.matches);
        }
        if (parsed.payments && Array.isArray(parsed.payments)) {
          this.payments = new Map(parsed.payments);
        }
        if (Array.isArray(parsed.swipes)) {
          this.swipes = parsed.swipes;
        }
        if (Array.isArray(parsed.messages)) {
          this.messages = parsed.messages;
        }
        if (Array.isArray(parsed.reports)) {
          this.reports = parsed.reports;
        }
        if (Array.isArray(parsed.dateRatings)) {
          this.dateRatings = parsed.dateRatings;
        }
        if (Array.isArray(parsed.demoUserIds)) {
          this.demoUserIds = new Set(parsed.demoUserIds);
        }
        if (parsed.staffMembers && Array.isArray(parsed.staffMembers)) {
          this.staffMembers = new Map(parsed.staffMembers);
        }

        if (this.staffMembers.size === 0) {
          this.seedInitialStaff();
        }

        logger.info(`💾 DataStore restored from disk: [${this.users.size}] users, [${this.staffMembers.size}] staff, [${this.messages.length}] messages, [${this.matches.size}] matches`);
        this.purgeDemoUsers();
        this.seedInitialData();
        return;
      }
    } catch (e: any) {
      logger.error('Failed to load persisted datastore from disk:', e.message);
    }

    this.seedInitialStaff();
    this.seedInitialData();
    this.saveToDisk();
  }

  private seedInitialStaff(): void {
    if (!this.staffMembers.has('staff-owner')) {
      this.staffMembers.set('staff-owner', {
        id: 'staff-owner',
        name: 'Ushara (Owner & Founder)',
        phone: '+94786799544',
        username: 'owner',
        role: 'super_admin',
        password: 'admin123',
        createdAt: new Date().toISOString(),
        isActive: true,
      });
    }
    if (!this.staffMembers.has('staff-admin')) {
      this.staffMembers.set('staff-admin', {
        id: 'staff-admin',
        name: 'Yaalu Head Moderator',
        phone: '+94770000000',
        username: 'admin',
        role: 'admin',
        password: 'admin123',
        createdAt: new Date().toISOString(),
        isActive: true,
      });
    }
  }

  // Purge fake demo profiles so only genuine accounts exist
  public purgeDemoUsers(): void {
    const demoPhones = new Set([
      '+94771234567',
      '+94772345678',
      '+94773456789',
      '+94774567890',
      '+447911123456',
    ]);

    const toDeleteIds = new Set<string>(this.demoUserIds);

    for (const [id, user] of this.users.entries()) {
      if (demoPhones.has(user.phone)) {
        toDeleteIds.add(id);
      }
    }

    if (toDeleteIds.size === 0) return;

    logger.info(`🧹 Purging [${toDeleteIds.size}] demo users and associated fake data...`);

    for (const id of toDeleteIds) {
      this.users.delete(id);
      this.profiles.delete(id);
      this.demoUserIds.delete(id);
    }

    // Remove swipes involving demo users
    this.swipes = this.swipes.filter(
      (s) => !toDeleteIds.has(s.fromUserId) && !toDeleteIds.has(s.toUserId)
    );

    // Remove matches involving demo users
    for (const [matchId, match] of this.matches.entries()) {
      if (toDeleteIds.has(match.user1Id) || toDeleteIds.has(match.user2Id)) {
        this.matches.delete(matchId);
      }
    }

    // Remove messages involving demo users
    this.messages = this.messages.filter(
      (m) => !toDeleteIds.has(m.senderId) && !toDeleteIds.has(m.receiverId)
    );

    // Remove ratings involving demo users
    this.dateRatings = this.dateRatings.filter(
      (r) => !toDeleteIds.has(r.fromUserId) && !toDeleteIds.has(r.toUserId)
    );

    this.saveToDisk();
    logger.info(`✅ Demo users purged. Active authentic users: [${this.users.size}]`);
  }

  public saveToDisk(): void {
    try {
      const dataDir = path.dirname(this.dataFilePath);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }

      const dump = {
        users: Array.from(this.users.entries()),
        profiles: Array.from(this.profiles.entries()),
        matches: Array.from(this.matches.entries()),
        payments: Array.from(this.payments.entries()),
        swipes: this.swipes,
        messages: this.messages,
        reports: this.reports,
        dateRatings: this.dateRatings,
        demoUserIds: Array.from(this.demoUserIds),
        staffMembers: Array.from(this.staffMembers.entries()),
        savedAt: new Date().toISOString(),
      };

      const tempPath = this.dataFilePath + '.tmp';
      fs.writeFileSync(tempPath, JSON.stringify(dump, null, 2), 'utf-8');
      fs.renameSync(tempPath, this.dataFilePath);
    } catch (err: any) {
      logger.error('Failed to persist datastore to disk:', err.message);
    }
  }

  public scheduleSave(): void {
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => {
      this.saveToDisk();
    }, 500);
  }

  // --- Staff Operations ---
  public getStaffMembers(): StaffMember[] {
    return Array.from(this.staffMembers.values()).filter((s) => s.isActive);
  }

  public addStaffMember(
    name: string,
    phone: string,
    username: string,
    role: StaffRole,
    password?: string
  ): StaffMember {
    const cleanPhone = phone.trim();
    const cleanUsername = username.trim().toLowerCase();
    const id = 'staff-' + uuidv4().substring(0, 8);
    const member: StaffMember = {
      id,
      name: name.trim(),
      phone: cleanPhone,
      username: cleanUsername,
      role,
      password: password || 'yaalu123',
      createdAt: new Date().toISOString(),
      isActive: true,
    };
    this.staffMembers.set(id, member);

    // If an existing user has this phone, update their role to match
    const existing = this.getUserByPhone(cleanPhone);
    if (existing) {
      existing.role = role === 'super_admin' ? 'admin' : (role as any);
      this.users.set(existing.id, existing);
    }

    this.scheduleSave();
    return member;
  }

  public removeStaffMember(staffId: string): boolean {
    const member = this.staffMembers.get(staffId);
    if (!member) return false;
    // Cannot delete the primary owner
    if (member.role === 'super_admin' || member.phone === '+94786799544') return false;

    member.isActive = false;
    this.staffMembers.set(staffId, member);

    const user = this.getUserByPhone(member.phone);
    if (user && user.role !== 'admin') {
      user.role = 'user';
      this.users.set(user.id, user);
    }

    this.scheduleSave();
    return true;
  }

  // --- User Operations ---
  public getUserByPhone(phone: string): User | undefined {
    for (const user of this.users.values()) {
      if (user.phone === phone && !user.isDeleted) return user;
    }
    return undefined;
  }

  public getUserById(id: string): User | undefined {
    const user = this.users.get(id);
    return user && !user.isDeleted ? user : undefined;
  }

  public getProfileByUserId(userId: string): UserProfile | undefined {
    const profile = this.profiles.get(userId);
    if (profile && profile.photos && Array.isArray(profile.photos)) {
      profile.photos = profile.photos.map((p) =>
        p.replace(/&amp;#x2F;/g, '/').replace(/&#x2F;/g, '/').replace(/&amp;/g, '&')
      );
    }
    return profile;
  }

  public createUser(phone: string, email?: string): { user: User; profile: UserProfile } {
    // Deterministic static UUIDs for master accounts so session tokens never invalidate across restarts
    const userId = phone === '+94786799544'
      ? '78679954-4000-4000-8000-000000000001'
      : phone === '+94770000000'
      ? '77000000-0000-4000-8000-000000000000'
      : uuidv4();
    const now = new Date().toISOString();

    const newUser: User = {
      id: userId,
      phone,
      email,
      role: 'user',
      isBanned: false,
      isDeleted: false,
      subscriptionTier: 'free',
      subscriptionExpiresAt: null,
      dailySwipeCount: 0,
      lastSwipeReset: now,
      superLikesRemaining: 1, // 1 free super like on signup
      freeTrialUsed: false,
      blockedUserIds: [],
      createdAt: now,
      updatedAt: now,
    };

    const newProfile: UserProfile = {
      id: uuidv4(),
      userId,
      displayName: '',
      age: 21,
      birthDate: '2003-01-01',
      gender: 'other',
      interestedIn: ['female', 'male'],
      bio: '',
      photos: [],
      interests: [],
      datingIntention: 'dating',
      homeDistrict: 'Colombo',
      location: {
        latitude: 6.9271, // Colombo default
        longitude: 79.8612,
        city: 'Colombo',
        country: 'Sri Lanka',
        isPassportActive: false,
      },
      isStealthMode: false,
      verificationStatus: 'unverified',
      boostedUntil: null,
      lastActive: now,
      createdAt: now,
    };

    this.users.set(userId, newUser);
    this.profiles.set(userId, newProfile);

    // Clean user registration without fake demo matches
    this.scheduleSave();
    return { user: newUser, profile: newProfile };
  }

  public updateUser(userId: string, updates: Partial<User>): User | undefined {
    const user = this.getUserById(userId);
    if (!user) return undefined;

    const updatedUser = { ...user, ...updates, updatedAt: new Date().toISOString() };
    this.users.set(userId, updatedUser);
    this.scheduleSave();
    return updatedUser;
  }

  public updateProfile(userId: string, updates: Partial<UserProfile>): UserProfile | undefined {
    const profile = this.getProfileByUserId(userId);
    if (!profile) return undefined;

    if (updates.photos && Array.isArray(updates.photos)) {
      updates.photos = updates.photos.map((p) =>
        p.replace(/&amp;#x2F;/g, '/').replace(/&#x2F;/g, '/').replace(/&amp;/g, '&')
      );
    }

    const updatedProfile = { ...profile, ...updates };
    this.profiles.set(userId, updatedProfile);
    this.scheduleSave();
    return updatedProfile;
  }

  // --- Discovery Engine & Swipe Stack ---
  public getDiscoveryProfiles(
    userId: string,
    maxDistanceKm: number = 50,
    minAge: number = 18,
    maxAge: number = 60
  ): Array<UserProfile & { distanceKm: number }> {
    const currentUser = this.getUserById(userId);
    const currentProfile = this.getProfileByUserId(userId);
    if (!currentUser || !currentProfile) return [];

    // Reset daily swipe count if 24 hours elapsed
    this.checkAndResetDailySwipes(currentUser);

    // Collect already swiped user IDs
    const swipedUserIds = new Set<string>();
    for (const swipe of this.swipes) {
      if (swipe.fromUserId === userId) {
        swipedUserIds.add(swipe.toUserId);
      }
    }

    const blockedSet = new Set(currentUser.blockedUserIds);
    const results: Array<UserProfile & { distanceKm: number }> = [];

    const userLat = currentProfile.location.latitude;
    const userLon = currentProfile.location.longitude;

    for (const [targetUserId, profile] of this.profiles.entries()) {
      // Exclude self, already swiped, blocked, banned
      if (targetUserId === userId) continue;
      if (swipedUserIds.has(targetUserId)) continue;
      if (blockedSet.has(targetUserId)) continue;

      const targetUser = this.getUserById(targetUserId);
      if (!targetUser || targetUser.isBanned || targetUser.isDeleted) continue;

      // Hide System Staff / Reviewer Accounts, BUT allow Admin's personal phone (+94786799544) to be shown!
      const isStaffOrReviewer =
        targetUser.phone === '+94770000000' ||
        targetUser.phone === '+94711111111' ||
        targetUser.id === 'yaalu-official-support' ||
        (targetUser.role !== 'user' && targetUser.phone !== '+94786799544');

      if (isStaffOrReviewer && currentUser.role !== 'admin') {
        continue;
      }

      // Stealth mode check: If target user enabled stealth, they are ONLY visible to people they swiped right on
      if (profile.isStealthMode) {
        const hasTargetSwipedUser = this.swipes.some(
          (s) => s.fromUserId === targetUserId && s.toUserId === userId && s.action === 'right'
        );
        if (!hasTargetSwipedUser) continue;
      }

      // Age filter
      if (profile.age < minAge || profile.age > maxAge) continue;

      // Heterosexual Couple Matching: Strictly opposite gender in discovery deck
      // Male users see Female profiles; Female users see Male profiles
      const curGender = (currentProfile.gender || '').toLowerCase();
      const tgtGender = (profile.gender || '').toLowerCase();
      if (curGender === 'male' && tgtGender !== 'female') continue;
      if (curGender === 'female' && tgtGender !== 'male') continue;

      // Calculate real geospatial distance (Haversine)
      const distance = calculateDistanceKm(
        userLat,
        userLon,
        profile.location.latitude,
        profile.location.longitude
      );

      // Distance limit: If current user is VIP with Passport active, they can bypass local distance limit
      const isVip = currentUser.subscriptionTier !== 'free';
      if (!isVip && distance > maxDistanceKm) continue;

      results.push({
        ...profile,
        distanceKm: distance,
      });
    }

    // Sort boosted profiles first, then by distance
    results.sort((a, b) => {
      const aBoosted = a.boostedUntil && new Date(a.boostedUntil) > new Date() ? 1 : 0;
      const bBoosted = b.boostedUntil && new Date(b.boostedUntil) > new Date() ? 1 : 0;
      if (aBoosted !== bBoosted) return bBoosted - aBoosted;
      return a.distanceKm - b.distanceKm;
    });

    return results;
  }

  // --- Real-time User Search Engine ---
  public searchProfiles(
    userId: string,
    options: {
      query?: string;
      district?: string;
      interest?: string;
      gender?: string;
      verifiedOnly?: boolean;
      minAge?: number;
      maxAge?: number;
    }
  ): Array<UserProfile & { distanceKm: number }> {
    const currentUser = this.getUserById(userId);
    const currentProfile = this.getProfileByUserId(userId);
    if (!currentUser || !currentProfile) return [];

    const blockedSet = new Set(currentUser.blockedUserIds);
    const results: Array<UserProfile & { distanceKm: number }> = [];

    const userLat = currentProfile.location.latitude;
    const userLon = currentProfile.location.longitude;

    const q = options.query?.trim().toLowerCase();
    const districtFilter = options.district?.trim().toLowerCase();
    const interestFilter = options.interest?.trim().toLowerCase();
    const genderFilter = options.gender?.trim().toLowerCase();

    for (const [targetUserId, profile] of this.profiles.entries()) {
      // Exclude self and blocked
      if (targetUserId === userId) continue;
      if (blockedSet.has(targetUserId)) continue;

      const targetUser = this.getUserById(targetUserId);
      if (!targetUser || targetUser.isBanned || targetUser.isDeleted) continue;

      // Hide System Staff / Reviewer Accounts, BUT allow Admin's personal phone (+94786799544) to be shown!
      const isStaffOrReviewer =
        targetUser.phone === '+94770000000' ||
        targetUser.phone === '+94711111111' ||
        targetUser.id === 'yaalu-official-support' ||
        (targetUser.role !== 'user' && targetUser.phone !== '+94786799544');

      if (isStaffOrReviewer && currentUser.role !== 'admin') {
        continue;
      }

      // Exclude stealth mode unless mutual interest
      if (profile.isStealthMode) {
        const hasTargetSwipedUser = this.swipes.some(
          (s) =>
            s.fromUserId === targetUserId &&
            s.toUserId === userId &&
            (s.action === 'right' || s.action === 'superlike')
        );
        if (!hasTargetSwipedUser) continue;
      }

      // Verified Only filter
      if (options.verifiedOnly && profile.verificationStatus !== 'verified') {
        continue;
      }

      // Gender filter (Default to opposite gender if not explicitly searching for a specific gender)
      if (genderFilter && genderFilter !== 'all') {
        if (profile.gender.toLowerCase() !== genderFilter) continue;
      } else {
        const curGender = (currentProfile.gender || '').toLowerCase();
        if (curGender === 'male' && profile.gender.toLowerCase() !== 'female') continue;
        if (curGender === 'female' && profile.gender.toLowerCase() !== 'male') continue;
      }

      // District filter
      if (districtFilter && districtFilter !== 'all') {
        const matchDistrict =
          (profile.homeDistrict || '').toLowerCase().includes(districtFilter) ||
          profile.location.city.toLowerCase().includes(districtFilter);
        if (!matchDistrict) continue;
      }

      // Interest filter
      if (interestFilter && interestFilter !== 'all') {
        const hasInterest = profile.interests.some((i) =>
          i.toLowerCase().includes(interestFilter)
        );
        if (!hasInterest) continue;
      }

      // Age range filter
      if (options.minAge && profile.age < options.minAge) continue;
      if (options.maxAge && profile.age > options.maxAge) continue;

      // Search keyword query (Name, Bio, District, Interests)
      if (q && q.length > 0) {
        const nameMatch = profile.displayName.toLowerCase().includes(q);
        const bioMatch = profile.bio.toLowerCase().includes(q);
        const districtMatch =
          (profile.homeDistrict || '').toLowerCase().includes(q) ||
          profile.location.city.toLowerCase().includes(q);
        const interestMatch = profile.interests.some((i) => i.toLowerCase().includes(q));

        if (!nameMatch && !bioMatch && !districtMatch && !interestMatch) {
          continue;
        }
      }

      const distance = calculateDistanceKm(
        userLat,
        userLon,
        profile.location.latitude,
        profile.location.longitude
      );

      results.push({
        ...profile,
        distanceKm: distance,
      });
    }

    // Sort: Verified and boosted first, then by closest distance
    results.sort((a, b) => {
      const aVerified = a.verificationStatus === 'verified' ? 1 : 0;
      const bVerified = b.verificationStatus === 'verified' ? 1 : 0;
      if (aVerified !== bVerified) return bVerified - aVerified;
      return a.distanceKm - b.distanceKm;
    });

    return results;
  }

  // --- Admin Dashboard & Moderation Operations ---
  public getAdminStats() {
    let totalUsers = 0;
    let verifiedUsers = 0;
    let bannedUsers = 0;
    let vipUsers = 0;

    for (const u of this.users.values()) {
      if (u.isDeleted) continue;
      totalUsers++;
      if (u.isBanned) bannedUsers++;
      if (u.subscriptionTier !== 'free') vipUsers++;
    }

    for (const p of this.profiles.values()) {
      if (p.verificationStatus === 'verified') verifiedUsers++;
    }

    let totalRevenue = 0;
    for (const pay of this.payments.values()) {
      if (pay.status === 'success') {
        totalRevenue += pay.amount;
      }
    }

    return {
      totalUsers,
      verifiedUsers,
      bannedUsers,
      vipUsers,
      totalMatches: this.matches.size,
      totalMessages: this.messages.length,
      totalReports: this.reports.length,
      totalPayments: this.payments.size,
      totalRevenueLkr: totalRevenue,
    };
  }

  public getAllUsersForAdmin(q?: string) {
    const list: any[] = [];
    const query = q?.toLowerCase().trim();

    for (const user of this.users.values()) {
      if (user.isDeleted) continue;
      const profile = this.profiles.get(user.id);
      if (query && query.length > 0) {
        const matchName = profile?.displayName.toLowerCase().includes(query);
        const matchPhone = user.phone.toLowerCase().includes(query);
        const matchDistrict = (profile?.homeDistrict || '').toLowerCase().includes(query);
        if (!matchName && !matchPhone && !matchDistrict) continue;
      }

      list.push({
        id: user.id,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isBanned: user.isBanned,
        subscriptionTier: user.subscriptionTier,
        subscriptionExpiresAt: user.subscriptionExpiresAt,
        displayName: profile?.displayName || 'Unnamed User',
        age: profile?.age || 20,
        gender: profile?.gender || 'other',
        homeDistrict: profile?.homeDistrict || 'Colombo',
        verificationStatus: profile?.verificationStatus || 'unverified',
        photos: profile?.photos || [],
        bio: profile?.bio || '',
        interests: profile?.interests || [],
        createdAt: user.createdAt,
      });
    }

    return list.reverse();
  }

  public setUserVerification(userId: string, isVerified: boolean): boolean {
    const profile = this.profiles.get(userId);
    if (!profile) return false;
    profile.verificationStatus = isVerified ? 'verified' : 'unverified';
    this.profiles.set(userId, profile);
    return true;
  }

  public setUserBanned(userId: string, isBanned: boolean): boolean {
    const user = this.users.get(userId);
    if (!user) return false;
    user.isBanned = isBanned;
    this.users.set(userId, user);
    return true;
  }

  public setUserSubscription(userId: string, tier: SubscriptionTier, durationDays: number): boolean {
    const user = this.users.get(userId);
    if (!user) return false;
    user.subscriptionTier = tier;
    user.subscriptionExpiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();
    user.superLikesRemaining += 5;
    this.users.set(userId, user);
    return true;
  }

  // Check and reset daily swipe quota (15 swipes/day for Free Tier)
  public checkAndResetDailySwipes(user: User): void {
    const lastReset = new Date(user.lastSwipeReset).getTime();
    const now = Date.now();
    const twentyFourHours = 24 * 60 * 60 * 1000;

    if (now - lastReset > twentyFourHours) {
      user.dailySwipeCount = 0;
      user.lastSwipeReset = new Date().toISOString();
      this.users.set(user.id, user);
    }
  }

  // --- Record Swipe & Atomic Match Engine ---
  public recordSwipe(
    fromUserId: string,
    toUserId: string,
    action: SwipeAction,
    superLikeMessage?: string
  ): { swipe: Swipe; isMatch: boolean; match?: Match } {
    const user = this.getUserById(fromUserId);
    if (!user) throw new Error('User not found');

    const isVip = user.subscriptionTier !== 'free';

    // Core app is 100% free with unlimited swipes for early user acquisition!
    this.checkAndResetDailySwipes(user);

    // Super Like check
    if (action === 'superlike') {
      if (user.superLikesRemaining <= 0) {
        throw new Error('NO_SUPER_LIKES_REMAINING');
      }
      user.superLikesRemaining -= 1;
    }

    user.dailySwipeCount += 1;
    this.users.set(user.id, user);

    const swipeId = uuidv4();
    const newSwipe: Swipe = {
      id: swipeId,
      fromUserId,
      toUserId,
      action,
      superLikeMessage,
      createdAt: new Date().toISOString(),
    };
    this.swipes.push(newSwipe);

    // Check mutual match condition
    let isMatch = false;
    let match: Match | undefined = undefined;

    if (action === 'right' || action === 'superlike') {
      // Find if toUserId has already swiped right or superliked fromUserId
      const counterpartSwipe = this.swipes.find(
        (s) =>
          s.fromUserId === toUserId &&
          s.toUserId === fromUserId &&
          (s.action === 'right' || s.action === 'superlike')
      );

      // Check if this match already exists
      const existingMatch = Array.from(this.matches.values()).find(
        (m) =>
          (m.user1Id === fromUserId && m.user2Id === toUserId) ||
          (m.user2Id === fromUserId && m.user1Id === toUserId)
      );

      if (existingMatch) {
        isMatch = true;
        match = existingMatch;
      } else if (counterpartSwipe) {
        isMatch = true;
        const matchId = uuidv4();
        match = {
          id: matchId,
          user1Id: fromUserId,
          user2Id: toUserId,
          createdAt: new Date().toISOString(),
          isActive: true,
        };
        this.matches.set(matchId, match);
        logger.info(`Match created between [${fromUserId}] and [${toUserId}]!`);
      }
    }

    this.scheduleSave();
    return { swipe: newSwipe, isMatch, match };
  }

  // Rewind last swipe (Supports both free and VIP undo)
  public rewindLastSwipe(userId: string): Swipe | null {
    const user = this.getUserById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Find the latest swipe from this user
    let lastIndex = -1;
    for (let i = this.swipes.length - 1; i >= 0; i--) {
      if (this.swipes[i].fromUserId === userId) {
        lastIndex = i;
        break;
      }
    }

    if (lastIndex === -1) return null;

    const [removedSwipe] = this.swipes.splice(lastIndex, 1);

    // If there was a match created because of this swipe, dissolve it
    for (const [matchId, match] of this.matches.entries()) {
      if (
        (match.user1Id === userId && match.user2Id === removedSwipe.toUserId) ||
        (match.user2Id === userId && match.user1Id === removedSwipe.toUserId)
      ) {
        this.matches.delete(matchId);
        break;
      }
    }

    return removedSwipe;
  }

  // --- Date Rating & Safety Verification Engine ---
  public addDateRating(
    fromUserId: string,
    toUserId: string,
    stars: number,
    tags: string[],
    review?: string
  ): DateRating {
    const rating: DateRating = {
      id: uuidv4(),
      fromUserId,
      toUserId,
      stars: Math.min(5, Math.max(1, stars)),
      tags: tags || [],
      review: review?.trim(),
      createdAt: new Date().toISOString(),
    };
    this.dateRatings.push(rating);
    logger.info(`Date rating recorded: User [${fromUserId}] rated User [${toUserId}] with [${stars}] stars.`);
    return rating;
  }

  public getDateRatingSummary(userId: string): {
    averageRating: number;
    totalRatings: number;
    tags: string[];
    badge: string;
  } {
    const ratings = this.dateRatings.filter((r) => r.toUserId === userId);
    if (ratings.length === 0) {
      return {
        averageRating: 5.0,
        totalRatings: 0,
        tags: ['New Yaalu Member', 'Verified Phone', 'Respectful Vibe'],
        badge: '⭐ New Member',
      };
    }
    const sum = ratings.reduce((acc, r) => acc + r.stars, 0);
    const avg = parseFloat((sum / ratings.length).toFixed(1));

    const tagCounts = new Map<string, number>();
    for (const r of ratings) {
      for (const t of r.tags) {
        tagCounts.set(t, (tagCounts.get(t) || 0) + 1);
      }
    }
    const sortedTags = Array.from(tagCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .map((e) => e[0])
      .slice(0, 5);

    let badge = '⭐ Top Rated Date';
    if (avg >= 4.8) badge = '🛡️ 100% Safe & Respectful';
    else if (avg >= 4.0) badge = '🤝 Highly Recommended';

    return {
      averageRating: avg,
      totalRatings: ratings.length,
      tags: sortedTags.length > 0 ? sortedTags : ['Respectful Companion', 'Safe Date'],
      badge,
    };
  }

  // Get Profiles that liked current user ("See Who Liked You" - Free for Females, VIP for Others)
  public getWhoLikedUser(userId: string): UserProfile[] {
    const user = this.getUserById(userId);
    const profile = this.getProfileByUserId(userId);
    const isFemale = profile?.gender?.toLowerCase() === 'female';
    const isVip = user && user.subscriptionTier !== 'free';

    if (!isVip && !isFemale) {
      throw new Error('VIP_REQUIRED_SEE_LIKES');
    }

    // Find all users who swiped right on userId
    const likerUserIds = this.swipes
      .filter((s) => s.toUserId === userId && (s.action === 'right' || s.action === 'superlike'))
      .map((s) => s.fromUserId);

    const profiles: UserProfile[] = [];
    for (const id of likerUserIds) {
      const p = this.getProfileByUserId(id);
      if (p) profiles.push(p);
    }
    return profiles;
  }

  // --- Matches & Messaging ---
  public getUserMatches(userId: string): Array<{ match: Match; otherUserProfile: UserProfile }> {
    const results: Array<{ match: Match; otherUserProfile: UserProfile }> = [];

    for (const match of this.matches.values()) {
      if (!match.isActive) continue;
      if (match.user1Id === userId || match.user2Id === userId) {
        const otherUserId = match.user1Id === userId ? match.user2Id : match.user1Id;
        const profile = this.getProfileByUserId(otherUserId);
        if (profile) {
          results.push({ match, otherUserProfile: profile });
        }
      }
    }

    return results;
  }

  public getMessagesForMatch(matchId: string, requestingUserId: string): Message[] {
    const match = this.matches.get(matchId);
    if (!match) throw new Error('Match not found');

    // IDOR Protection: User MUST be a participant of the match
    if (match.user1Id !== requestingUserId && match.user2Id !== requestingUserId) {
      logger.securityAlert('UNAUTHORIZED_MATCH_ACCESS_ATTEMPT', {
        matchId,
        requestingUserId,
      });
      throw new Error('FORBIDDEN_MATCH_ACCESS');
    }

    const matchMessages = this.messages.filter((m) => m.matchId === matchId);
    // Deduplicate any accidental duplicates
    const unique: Message[] = [];
    for (const m of matchMessages) {
      const isDup = unique.some(
        (u) =>
          u.id === m.id ||
          (u.senderId === m.senderId &&
            u.content === m.content &&
            Math.abs(new Date(u.createdAt).getTime() - new Date(m.createdAt).getTime()) < 2500)
      );
      if (!isDup) {
        unique.push(m);
      }
    }
    return unique;
  }

  public addMessage(
    matchId: string,
    senderId: string,
    content: string,
    mediaUrl?: string,
    isVoiceNote: boolean = false
  ): Message {
    const match = this.matches.get(matchId);
    if (!match || !match.isActive) throw new Error('Invalid match');

    // IDOR verification
    if (match.user1Id !== senderId && match.user2Id !== senderId) {
      throw new Error('FORBIDDEN_MESSAGE_SEND');
    }

    // Deduplication guard: Check if an identical message was sent in this match from this sender within 2.5 seconds
    const recentDuplicate = this.messages.slice(-10).reverse().find(
      (m) =>
        m.matchId === matchId &&
        m.senderId === senderId &&
        m.content === content &&
        Date.now() - new Date(m.createdAt).getTime() < 2500
    );
    if (recentDuplicate) {
      logger.info(`Duplicate message submission prevented for match [${matchId}]: "${content}"`);
      return recentDuplicate;
    }

    const receiverId = match.user1Id === senderId ? match.user2Id : match.user1Id;
    const now = new Date().toISOString();

    const msg: Message = {
      id: uuidv4(),
      matchId,
      senderId,
      receiverId,
      content,
      mediaUrl,
      isBlurred: mediaUrl ? true : false, // Default blur for sensitive media protection
      isVoiceNote,
      isRead: false,
      createdAt: now,
    };

    this.messages.push(msg);
    match.lastMessageAt = now;
    this.matches.set(matchId, match);
    this.scheduleSave();

    return msg;
  }

  // Toggle blur for photo message (user consent)
  public toggleMessageBlur(messageId: string, requestingUserId: string): Message {
    const msg = this.messages.find((m) => m.id === messageId);
    if (!msg) throw new Error('Message not found');

    if (msg.receiverId !== requestingUserId && msg.senderId !== requestingUserId) {
      throw new Error('FORBIDDEN');
    }

    msg.isBlurred = !msg.isBlurred;
    return msg;
  }

  // Report User (Apple Guideline 1.2 & Google Play UGC Requirement)
  public createReport(
    reporterId: string,
    reportedUserId: string,
    reason: Report['reason'],
    description?: string
  ): Report {
    const report: Report = {
      id: uuidv4(),
      reporterId,
      reportedUserId,
      reason,
      description,
      createdAt: new Date().toISOString(),
    };
    this.reports.push(report);

    // Auto-block reported user for the reporter
    const reporter = this.getUserById(reporterId);
    if (reporter && !reporter.blockedUserIds.includes(reportedUserId)) {
      reporter.blockedUserIds.push(reportedUserId);
      this.users.set(reporterId, reporter);
    }

    logger.info(`User [${reporterId}] reported user [${reportedUserId}] for [${reason}]`);
    return report;
  }

  // Block User
  public blockUser(userId: string, targetUserId: string): void {
    const user = this.getUserById(userId);
    if (!user) return;
    if (!user.blockedUserIds.includes(targetUserId)) {
      user.blockedUserIds.push(targetUserId);
      this.users.set(userId, user);
    }
  }

  // Account Deletion (Apple Guideline 5.1.1(v) & GDPR requirement)
  public deleteUserAccount(userId: string): void {
    const user = this.users.get(userId);
    if (user) {
      user.isDeleted = true;
      user.phone = `deleted_${uuidv4()}`;
      user.email = undefined;
      this.users.set(userId, user);
    }
    this.profiles.delete(userId);
    // Deactivate matches
    for (const match of this.matches.values()) {
      if (match.user1Id === userId || match.user2Id === userId) {
        match.isActive = false;
      }
    }
    logger.info(`Account permanently deleted: [${userId}]`);
    this.scheduleSave();
  }

  // VIP Subscription Activation (PayHere / Bank Transfer / Apple / Google IAP)
  public activateSubscription(
    userId: string,
    tier: SubscriptionTier,
    provider: 'payhere' | 'apple_iap' | 'google_play' | 'bank_transfer',
    amount: number,
    orderId: string,
    extra?: { bankName?: string; referenceCode?: string; slipNote?: string }
  ): PaymentTransaction {
    const user = this.getUserById(userId);
    if (!user) throw new Error('User not found');

    const durationDays =
      tier === 'vip_weekly' ? 7 : tier === 'vip_monthly' ? 30 : tier === 'vip_3month' ? 90 : 365;

    const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

    user.subscriptionTier = tier;
    user.subscriptionExpiresAt = expiresAt;
    user.superLikesRemaining += 5; // Add VIP Super Likes
    this.users.set(userId, user);

    const transaction: PaymentTransaction = {
      id: uuidv4(),
      userId,
      orderId,
      amount,
      currency: 'LKR',
      tier,
      provider,
      status: 'success',
      bankName: extra?.bankName,
      referenceCode: extra?.referenceCode,
      slipNote: extra?.slipNote,
      createdAt: new Date().toISOString(),
    };
    this.payments.set(transaction.id, transaction);

    logger.info(`VIP Activated for user [${userId}], Tier: [${tier}], Provider: [${provider}], Expires: [${expiresAt}]`);
    this.scheduleSave();
    return transaction;
  }

  // Seed master administrators only (No fake demo profiles)
  private seedInitialData() {
    this.purgeDemoUsers();

    // 1. Seed Yaalu Master Administrator (+94770000000)
    const adminPhone = '+94770000000';
    let adminUser = this.getUserByPhone(adminPhone);
    if (!adminUser) {
      const { user, profile } = this.createUser(adminPhone, 'admin@yaalu.lk');
      user.role = 'admin';
      user.subscriptionTier = 'vip_annual';
      this.users.set(user.id, user);
      profile.displayName = 'Yaalu Admin';
      profile.bio = 'Yaalu Official System Administrator & Security Lead';
      profile.verificationStatus = 'verified';
      profile.photos = ['https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80'];
      this.updateProfile(user.id, profile);
    }

    // 2. Seed Yaalu Platform Owner (+94786799544)
    const ownerPhone = '+94786799544';
    let ownerUser = this.getUserByPhone(ownerPhone);
    if (!ownerUser) {
      const { user, profile } = this.createUser(ownerPhone, 'owner@yaalu.lk');
      user.role = 'admin';
      user.subscriptionTier = 'vip_annual';
      user.superLikesRemaining = 999;
      this.users.set(user.id, user);
      profile.displayName = 'Ushara';
      profile.bio = 'Yaalu Platform Owner';
      profile.verificationStatus = 'verified';
      profile.photos = ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80'];
      this.updateProfile(user.id, profile);
    }

    this.saveToDisk();
  }
}

export const db = new DataStore();
