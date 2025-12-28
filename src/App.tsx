import { useState, createContext, useContext, useEffect } from 'react';
import { AuthProvider } from './context/AuthContext';
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
import EventDetails from './pages/EventDetails';
import TermsPage from './pages/TermsPage';
import BonusTermsPage from './pages/BonusTermsPage';
import Support from './pages/Support';
import LegalHub from './pages/LegalHub';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';

type PageType = 'home' | 'markets' | 'futures' | 'profile' | 'swap' | 'swaphistory' | 'copytrading' | 'mocktrading' | 'activecopying' | 'traderprofile' | 'deposit' | 'withdraw' | 'kyc' | 'kycdocuments' | 'adminkyc' | 'wallet' | 'referral' | 'affiliate' | 'vip' | 'rewardshub' | 'earn' | 'signin' | 'signup' | 'forgotpassword' | 'resetpassword' | 'transactions' | 'admindashboard' | 'adminuser' | 'admintrader' | 'adminlogs' | 'admincrm' | 'adminemails' | 'adminbonuses' | 'adminsupport' | 'adminviptracking' | 'adminsharkcards' | 'adminstaff' | 'admintelegram' | 'adminwithdrawals' | 'admindeposits' | 'event' | 'terms' | 'bonusterms' | 'support' | 'legal';

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
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const type = hashParams.get('type');
    const accessToken = hashParams.get('access_token');

    if (type === 'recovery' && accessToken) {
      setCurrentPage('resetpassword');
      return;
    }

    const urlParams = new URLSearchParams(window.location.search);

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
  }, []);

  useEffect(() => {
    localStorage.setItem('currentPage', currentPage);
  }, [currentPage]);

  const navigateTo = (page: PageType, state?: any) => {
    setCurrentPage(page);
    setNavigationState(state);
  };

  const renderPage = () => {
    switch (currentPage) {
      case 'home':
        return <HomePage />;
      case 'markets':
        return <Markets />;
      case 'futures':
        return <FuturesTrading />;
      case 'swap':
        return <Swap />;
      case 'swaphistory':
        return <SwapHistory />;
      case 'copytrading':
        return <CopyTrading />;
      case 'mocktrading':
        return <MockTrading />;
      case 'activecopying':
        return <ActiveCopyTrading />;
      case 'traderprofile':
        return <TraderProfile />;
      case 'deposit':
        return <Deposit />;
      case 'withdraw':
        return <Withdraw />;
      case 'kyc':
        return <KYC />;
      case 'kycdocuments':
        return <KYCDocuments />;
      case 'adminkyc':
        return <AdminKYC />;
      case 'wallet':
        return <Wallet />;
      case 'referral':
        return <Referral />;
      case 'affiliate':
        return <AffiliateProgram />;
      case 'vip':
        return <VIPProgram />;
      case 'rewardshub':
        return <RewardsHub />;
      case 'earn':
        return <Earn />;
      case 'profile':
        return <Profile />;
      case 'signin':
        return <SignIn />;
      case 'signup':
        return <SignUp />;
      case 'forgotpassword':
        return <ForgotPassword />;
      case 'resetpassword':
        return <ResetPassword />;
      case 'transactions':
        return <Transactions />;
      case 'admindashboard':
        return <AdminDashboard />;
      case 'adminuser':
        return <AdminUserDetail />;
      case 'admintrader':
        return <AdminManagedTrader />;
      case 'adminlogs':
        return <AdminLogs />;
      case 'admincrm':
        return <AdminCRM />;
      case 'adminemails':
        return <AdminEmailTemplates />;
      case 'adminbonuses':
        return <AdminBonusTypes />;
      case 'adminsupport':
        return <AdminSupport />;
      case 'adminviptracking':
        return <AdminVIPTracking />;
      case 'adminsharkcards':
        return <AdminSharkCards />;
      case 'adminstaff':
        return <AdminStaffManagement />;
      case 'admintelegram':
        return <AdminTelegramCRM />;
      case 'adminwithdrawals':
        return <AdminWithdrawals />;
      case 'admindeposits':
        return <AdminDeposits />;
      case 'event':
        return <EventDetails />;
      case 'terms':
        return <TermsPage />;
      case 'bonusterms':
        return <BonusTermsPage />;
      case 'support':
        return <Support />;
      case 'legal':
        return <LegalHub />;
      default:
        return <HomePage />;
    }
  };

  return (
    <AuthProvider>
      <NavigationContext.Provider value={{ currentPage, navigateTo, navigationState }}>
        {renderPage()}
      </NavigationContext.Provider>
    </AuthProvider>
  );
}

export default App;
