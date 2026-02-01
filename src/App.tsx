import { useState, createContext, useContext, useEffect } from 'react';
import { AuthProvider } from './context/AuthContext';
import PopupBanner from './components/PopupBanner';
import PageTracker from './components/PageTracker';
import CookieConsentBanner from './components/CookieConsentBanner';
import { initAcquisitionTracking } from './services/acquisitionService';
import { priceSyncService } from './services/priceSyncService';
import HomePage from './pages/HomePage';
import Markets from './pages/Markets';
import FuturesTrading from './pages/FuturesTrading';
import Profile from './pages/Profile';
import Swap from './pages/Swap';
import SwapHistory from './pages/SwapHistory';
import CopyTrading from './pages/CopyTrading';
import MockTrading from './pages/MockTrading';
import ActiveCopyTrading from './pages/ActiveCopyTrading';
import Deposit from './pages/Deposit';
import Withdraw from './pages/Withdraw';
import KYC from './pages/KYC';
import Wallet from './pages/Wallet';
import Referral from './pages/Referral';
import AffiliateProgram from './pages/AffiliateProgram';
import VIPProgram from './pages/VIPProgram';
import RewardsHub from './pages/RewardsHub';
import Earn from './pages/Earn';
import SignIn from './pages/SignIn';
import SignUp from './pages/SignUp';
import Transactions from './pages/Transactions';
import KYCDocuments from './pages/KYCDocuments';
import AdminKYC from './pages/AdminKYC';
import TraderProfile from './pages/TraderProfile';
import AdminDashboard from './pages/AdminDashboard';
import AdminUserDetail from './pages/AdminUserDetail';
import AdminManagedTrader from './pages/AdminManagedTrader';
import AdminLogs from './pages/AdminLogs';
import AdminCRM from './pages/AdminCRM';
import AdminEmailTemplates from './pages/AdminEmailTemplates';
import AdminBonusTypes from './pages/AdminBonusTypes';
import AdminSupport from './pages/AdminSupport';
import AdminVIPTracking from './pages/AdminVIPTracking';
import AdminSharkCards from './pages/AdminSharkCards';
import AdminStaffManagement from './pages/AdminStaffManagement';
import AdminTelegramCRM from './pages/AdminTelegramCRM';
import AdminWithdrawals from './pages/AdminWithdrawals';
import AdminDeposits from './pages/AdminDeposits';
import AdminReferralTracking from './pages/AdminReferralTracking';
import AdminPopupBanners from './pages/AdminPopupBanners';
import AdminGiveaway from './pages/AdminGiveaway';
import AdminAcquisition from './pages/AdminAcquisition';
import AdminExclusiveAffiliates from './pages/AdminExclusiveAffiliates';
import AdminPhoneRevealRequests from './pages/AdminPhoneRevealRequests';
import AdminStaffActivityLogs from './pages/AdminStaffActivityLogs';
import GiveawayHub from './pages/GiveawayHub';
import EventDetails from './pages/EventDetails';
import TermsPage from './pages/TermsPage';
import BonusTermsPage from './pages/BonusTermsPage';
import Support from './pages/Support';
import LegalHub from './pages/LegalHub';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';
import CopyTradingLandingPage from './pages/CopyTradingLandingPage';
import PrivacyPolicy from './pages/PrivacyPolicy';
import NoDepositBonus from './pages/NoDepositBonus';
import ReviewBonus from './pages/ReviewBonus';
import ReferFriendsBonus from './pages/ReferFriendsBonus';

type PageType = 'home' | 'markets' | 'futures' | 'profile' | 'swap' | 'swaphistory' | 'copytrading' | 'mocktrading' | 'activecopying' | 'traderprofile' | 'deposit' | 'withdraw' | 'kyc' | 'kycdocuments' | 'adminkyc' | 'wallet' | 'referral' | 'affiliate' | 'vip' | 'rewardshub' | 'earn' | 'signin' | 'signup' | 'forgotpassword' | 'resetpassword' | 'transactions' | 'admindashboard' | 'adminuser' | 'adminuserdetail' | 'admintrader' | 'adminlogs' | 'admincrm' | 'adminemails' | 'adminbonuses' | 'adminsupport' | 'adminviptracking' | 'adminsharkcards' | 'adminstaff' | 'admintelegram' | 'adminwithdrawals' | 'admindeposits' | 'adminreferrals' | 'adminpopups' | 'admingiveaway' | 'adminacquisition' | 'adminexclusiveaffiliates' | 'adminphonereveals' | 'adminstafflogs' | 'giveaway' | 'event' | 'terms' | 'bonusterms' | 'support' | 'legal' | 'privacy' | 'lp' | 'nodepositbonus' | 'reviewbonus' | 'referfriendsbonus';

interface NavigationContextType {
  currentPage: PageType;
  navigateTo: (page: PageType, state?: any) => void;
  navigationState?: any;
}

const NavigationContext = createContext<NavigationContextType | undefined>(undefined);

export const useNavigation = () => {
  const context = useContext(NavigationContext);
  if (!context) {
    throw new Error('useNavigation must be used within NavigationProvider');
  }
  return context;
};

function App() {
  const [currentPage, setCurrentPage] = useState<PageType>(() => {
    const saved = localStorage.getItem('currentPage');
    return (saved as PageType) || 'home';
  });
  const [navigationState, setNavigationState] = useState<any>();

  useEffect(() => {
    initAcquisitionTracking();
    priceSyncService.start();

    const pathname = window.location.pathname;
    if (pathname === '/lp') {
      setCurrentPage('lp');
      return;
    }
    if (pathname === '/privacy') {
      setCurrentPage('privacy');
      return;
    }
    if (pathname === '/futures') {
      setCurrentPage('futures');
      return;
    }
    if (pathname === '/copy-trading') {
      setCurrentPage('copytrading');
      return;
    }
    if (pathname === '/no-deposit-bonus') {
      setCurrentPage('nodepositbonus');
      return;
    }
    if (pathname === '/review-bonus') {
      setCurrentPage('reviewbonus');
      return;
    }
    if (pathname === '/refer-friends-bonus' || pathname === '/referral-bonus') {
      setCurrentPage('referfriendsbonus');
      return;
    }

    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const type = hashParams.get('type');
    const accessToken = hashParams.get('access_token');

    if (type === 'recovery' && accessToken) {
      setCurrentPage('resetpassword');
      return;
    }

    const urlParams = new URLSearchParams(window.location.search);

    const pageParam = urlParams.get('page');
    if (pageParam) {
      const validPages: PageType[] = ['home', 'markets', 'futures', 'profile', 'swap', 'swaphistory', 'copytrading', 'mocktrading', 'activecopying', 'deposit', 'withdraw', 'kyc', 'wallet', 'referral', 'affiliate', 'vip', 'rewardshub', 'earn', 'signin', 'signup', 'transactions', 'giveaway', 'support', 'legal', 'terms'];
      if (validPages.includes(pageParam as PageType)) {
        setCurrentPage(pageParam as PageType);
        window.history.replaceState({}, document.title, window.location.pathname);
        return;
      }
    }

    if (urlParams.get('reset') === 'true') {
      setCurrentPage('resetpassword');
      return;
    }

    const refCode = urlParams.get('ref');
    if (refCode) {
      const upperRefCode = refCode.toUpperCase();
      localStorage.setItem('pendingReferralCode', upperRefCode);
      setCurrentPage('signup');
      setNavigationState({ referralCode: upperRefCode });
      window.history.replaceState({}, document.title, window.location.pathname);
    }

    return () => {
      priceSyncService.stop();
    };
  }, []);

  useEffect(() => {
    localStorage.setItem('currentPage', currentPage);
  }, [currentPage]);

  const navigateTo = (page: PageType, state?: any) => {
    setCurrentPage(page);
    setNavigationState(state);
  };

  useEffect(() => {
    const handleAppNavigate = (event: CustomEvent<{ page: string; state?: any }>) => {
      const { page, state } = event.detail;
      setCurrentPage(page as PageType);
      if (state) setNavigationState(state);
    };

    window.addEventListener('app-navigate', handleAppNavigate as EventListener);
    return () => {
      window.removeEventListener('app-navigate', handleAppNavigate as EventListener);
    };
  }, []);

  const getPageTitle = (page: PageType): string => {
    const titles: Record<PageType, string> = {
      home: 'Home',
      markets: 'Markets',
      futures: 'Futures Trading',
      profile: 'Profile',
      swap: 'Swap',
      swaphistory: 'Swap History',
      copytrading: 'Copy Trading',
      mocktrading: 'Mock Trading',
      activecopying: 'Active Copy Trading',
      traderprofile: 'Trader Profile',
      deposit: 'Deposit',
      withdraw: 'Withdraw',
      kyc: 'KYC Verification',
      kycdocuments: 'KYC Documents',
      adminkyc: 'Admin KYC',
      wallet: 'Wallet',
      referral: 'Referral Program',
      affiliate: 'Affiliate Program',
      vip: 'VIP Program',
      rewardshub: 'Rewards Hub',
      earn: 'Earn',
      signin: 'Sign In',
      signup: 'Sign Up',
      forgotpassword: 'Forgot Password',
      resetpassword: 'Reset Password',
      transactions: 'Transactions',
      admindashboard: 'Admin Dashboard',
      adminuser: 'Admin User Details',
      adminuserdetail: 'Admin User Details',
      admintrader: 'Admin Managed Trader',
      adminlogs: 'Admin Logs',
      admincrm: 'Admin CRM',
      adminemails: 'Admin Email Templates',
      adminbonuses: 'Admin Bonus Types',
      adminsupport: 'Admin Support',
      adminviptracking: 'Admin VIP Tracking',
      adminsharkcards: 'Admin Shark Cards',
      adminstaff: 'Admin Staff Management',
      admintelegram: 'Admin Telegram CRM',
      adminwithdrawals: 'Admin Withdrawals',
      admindeposits: 'Admin Deposits',
      adminreferrals: 'Admin Referrals',
      adminpopups: 'Admin Popups',
      admingiveaway: 'Admin Giveaway',
      adminacquisition: 'Admin Acquisition',
      adminexclusiveaffiliates: 'Admin Exclusive Affiliates',
      adminphonereveals: 'Admin Phone Reveals',
      adminstafflogs: 'Admin Staff Logs',
      giveaway: 'Giveaway Hub',
      event: 'Event Details',
      terms: 'Terms & Conditions',
      bonusterms: 'Bonus Terms',
      support: 'Support',
      legal: 'Legal Hub',
      privacy: 'Privacy Policy',
      lp: 'Copy Trading',
      nodepositbonus: 'Verification Bonus - Get $25 Free USDT',
      reviewbonus: 'KYC + TrustPilot Bonus - Earn $25 USDT',
      referfriendsbonus: 'Refer Friends & Earn Up to 70% Commission'
    };
    return titles[page] || page;
  };

  const renderPage = () => {
    const pageTitle = getPageTitle(currentPage);
    const pagePath = `/${currentPage}`;

    const wrapWithTracker = (component: JSX.Element) => (
      <PageTracker pagePath={pagePath} pageTitle={pageTitle}>
        {component}
      </PageTracker>
    );
    switch (currentPage) {
      case 'home':
        return wrapWithTracker(<HomePage />);
      case 'markets':
        return wrapWithTracker(<Markets />);
      case 'futures':
        return wrapWithTracker(<FuturesTrading />);
      case 'swap':
        return wrapWithTracker(<Swap />);
      case 'swaphistory':
        return wrapWithTracker(<SwapHistory />);
      case 'copytrading':
        return wrapWithTracker(<CopyTrading />);
      case 'mocktrading':
        return wrapWithTracker(<MockTrading />);
      case 'activecopying':
        return wrapWithTracker(<ActiveCopyTrading />);
      case 'traderprofile':
        return wrapWithTracker(<TraderProfile />);
      case 'deposit':
        return wrapWithTracker(<Deposit />);
      case 'withdraw':
        return wrapWithTracker(<Withdraw />);
      case 'kyc':
        return wrapWithTracker(<KYC />);
      case 'kycdocuments':
        return wrapWithTracker(<KYCDocuments />);
      case 'adminkyc':
        return wrapWithTracker(<AdminKYC />);
      case 'wallet':
        return wrapWithTracker(<Wallet />);
      case 'referral':
        return wrapWithTracker(<Referral />);
      case 'affiliate':
        return wrapWithTracker(<AffiliateProgram />);
      case 'vip':
        return wrapWithTracker(<VIPProgram />);
      case 'rewardshub':
        return wrapWithTracker(<RewardsHub />);
      case 'earn':
        return wrapWithTracker(<Earn />);
      case 'profile':
        return wrapWithTracker(<Profile />);
      case 'signin':
        return wrapWithTracker(<SignIn />);
      case 'signup':
        return wrapWithTracker(<SignUp />);
      case 'forgotpassword':
        return wrapWithTracker(<ForgotPassword />);
      case 'resetpassword':
        return wrapWithTracker(<ResetPassword />);
      case 'transactions':
        return wrapWithTracker(<Transactions />);
      case 'admindashboard':
        return wrapWithTracker(<AdminDashboard />);
      case 'adminuser':
        return wrapWithTracker(<AdminUserDetail />);
      case 'admintrader':
        return wrapWithTracker(<AdminManagedTrader />);
      case 'adminlogs':
        return wrapWithTracker(<AdminLogs />);
      case 'admincrm':
        return wrapWithTracker(<AdminCRM />);
      case 'adminemails':
        return wrapWithTracker(<AdminEmailTemplates />);
      case 'adminbonuses':
        return wrapWithTracker(<AdminBonusTypes />);
      case 'adminsupport':
        return wrapWithTracker(<AdminSupport />);
      case 'adminviptracking':
        return wrapWithTracker(<AdminVIPTracking />);
      case 'adminsharkcards':
        return wrapWithTracker(<AdminSharkCards />);
      case 'adminstaff':
        return wrapWithTracker(<AdminStaffManagement />);
      case 'admintelegram':
        return wrapWithTracker(<AdminTelegramCRM />);
      case 'adminwithdrawals':
        return wrapWithTracker(<AdminWithdrawals />);
      case 'admindeposits':
        return wrapWithTracker(<AdminDeposits />);
      case 'adminreferrals':
        return wrapWithTracker(<AdminReferralTracking />);
      case 'adminpopups':
        return wrapWithTracker(<AdminPopupBanners />);
      case 'admingiveaway':
        return wrapWithTracker(<AdminGiveaway />);
      case 'adminacquisition':
        return wrapWithTracker(<AdminAcquisition />);
      case 'adminexclusiveaffiliates':
        return wrapWithTracker(<AdminExclusiveAffiliates />);
      case 'adminphonereveals':
        return wrapWithTracker(<AdminPhoneRevealRequests />);
      case 'adminstafflogs':
        return wrapWithTracker(<AdminStaffActivityLogs />);
      case 'giveaway':
        return wrapWithTracker(<GiveawayHub />);
      case 'event':
        return wrapWithTracker(<EventDetails />);
      case 'terms':
        return wrapWithTracker(<TermsPage />);
      case 'bonusterms':
        return wrapWithTracker(<BonusTermsPage />);
      case 'support':
        return wrapWithTracker(<Support />);
      case 'legal':
        return wrapWithTracker(<LegalHub />);
      case 'privacy':
        return wrapWithTracker(<PrivacyPolicy />);
      case 'lp':
        return wrapWithTracker(<CopyTradingLandingPage />);
      case 'nodepositbonus':
        return wrapWithTracker(<NoDepositBonus />);
      case 'reviewbonus':
        return wrapWithTracker(<ReviewBonus />);
      case 'referfriendsbonus':
        return wrapWithTracker(<ReferFriendsBonus />);
      default:
        return wrapWithTracker(<HomePage />);
    }
  };

  const isLandingPage = currentPage === 'lp';

  return (
    <AuthProvider>
      <NavigationContext.Provider value={{ currentPage, navigateTo, navigationState }}>
        {!isLandingPage && <PopupBanner />}
        {renderPage()}
        <CookieConsentBanner />
      </NavigationContext.Provider>
    </AuthProvider>
  );
}

export default App;
