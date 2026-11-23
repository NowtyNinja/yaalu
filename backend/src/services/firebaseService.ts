// Re-export from smsService (Firebase removed in favor of Notify.lk native SMS OTP)
export { smsService, firebaseService } from './smsService';
export type { SmsConfigData as FirebaseConfigData, SmsLogEntry } from './smsService';
