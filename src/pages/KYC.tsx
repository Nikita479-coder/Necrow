import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Shield, CheckCircle2, Upload, User, MapPin, CreditCard, FileText, Camera, AlertCircle, Building2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import { ToastContainer } from '../components/Toast';

type VerificationType = 'individual' | 'business';
type VerificationLevel = 'none' | 'basic' | 'intermediate' | 'advanced' | 'entity';

interface KYCData {
  user_id: string;
  verification_type: VerificationType;
  kyc_level: number;
  kyc_status: string;
  first_name?: string;
  last_name?: string;
  date_of_birth?: string;
  nationality?: string;
  address?: string;
  city?: string;
  postal_code?: string;
  country?: string;
  id_type?: string;
  company_name?: string;
  company_country?: string;
  incorporation_date?: string;
  business_nature?: string;
  tax_id?: string;
}

function KYC() {
  const { user, refreshProfile } = useAuth();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [verificationType, setVerificationType] = useState<VerificationType>('individual');
  const [currentStep, setCurrentStep] = useState(1);
  const [kycLevel, setKycLevel] = useState<VerificationLevel>('none');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [existingKYC, setExistingKYC] = useState<any>(null);

  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    dateOfBirth: '',
    nationality: '',
    address: '',
    city: '',
    postalCode: '',
    country: '',
    idType: 'passport',
    companyName: '',
    companyCountry: '',
    incorporationDate: '',
    businessNature: '',
    taxId: '',
  });

  const [uploadedFiles, setUploadedFiles] = useState({
    idFront: null as File | null,
    idBack: null as File | null,
    selfie: null as File | null,
    proofOfAddress: null as File | null,
    businessDoc: null as File | null,
  });

  const [uploadedDocuments, setUploadedDocuments] = useState<{[key: string]: boolean}>({});

  useEffect(() => {
    if (user) {
      loadKYCData();
      loadUploadedDocuments();
    }
  }, [user]);


  const loadUploadedDocuments = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('kyc_documents')
        .select('document_type')
        .eq('user_id', user.id);

      if (error) throw error;

      const uploaded: {[key: string]: boolean} = {};
      data?.forEach(doc => {
        uploaded[doc.document_type] = true;
      });
      setUploadedDocuments(uploaded);
    } catch (error) {
      console.error('Error loading uploaded documents:', error);
    }
  };

  const loadKYCData = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('kyc_verifications')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        console.error('Error loading KYC data:', error);
      }

      if (data) {
        setExistingKYC(data);
        setVerificationType(data.verification_type || 'individual');

        const level = data.kyc_level;
        if (level === 0) setKycLevel('none');
        else if (level === 1) setKycLevel('basic');
        else if (level === 2) setKycLevel('intermediate');
        else if (level === 3) setKycLevel('advanced');
        else if (level === 4) setKycLevel('entity');

        setFormData({
          firstName: data.first_name || '',
          lastName: data.last_name || '',
          dateOfBirth: data.date_of_birth || '',
          nationality: data.nationality || '',
          address: data.address || '',
          city: data.city || '',
          postalCode: data.postal_code || '',
          country: data.country || '',
          idType: data.id_type || 'passport',
          companyName: data.company_name || '',
          companyCountry: data.company_country || '',
          incorporationDate: data.incorporation_date || '',
          businessNature: data.business_nature || '',
          taxId: data.tax_id || '',
        });

        if (data.kyc_status === 'verified') {
          // Map verified levels to the next available step
          // Level 0 (none) -> Step 1, Level 1 (basic) -> Step 2, Level 2 (intermediate) -> Step 4
          if (level === 0) setCurrentStep(1);
          else if (level === 1) setCurrentStep(2);
          else if (level === 2) setCurrentStep(4); // Skip step 3, go to face verification
          else if (level >= 3) setCurrentStep(4);
        } else if (data.kyc_status === 'pending') {
          if (level === 1) setCurrentStep(2);
          else if (level === 2) setCurrentStep(4);
          else if (level === 3) setCurrentStep(4);
        }
      }
    } catch (error) {
      console.error('Error loading KYC data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = async (field: keyof typeof uploadedFiles, event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file || !user) return;

    if (file.size > 10 * 1024 * 1024) {
      showError('File size must be less than 10MB');
      return;
    }

    setUploadedFiles({ ...uploadedFiles, [field]: file });

    const documentTypeMap: {[key: string]: string} = {
      idFront: 'id_front',
      idBack: 'id_back',
      selfie: 'selfie',
      proofOfAddress: 'proof_address',
      businessDoc: 'business_doc'
    };

    const reader = new FileReader();

    reader.onload = async (e) => {
      try {
        const base64String = (e.target?.result as string).split(',')[1];

        const { error } = await supabase.rpc('insert_kyc_document', {
          p_user_id: user.id,
          p_document_type: documentTypeMap[field],
          p_file_name: file.name,
          p_file_size: file.size,
          p_mime_type: file.type,
          p_file_data_base64: base64String,
        });

        if (error) {
          console.error('Database error:', error);
          showError('Failed to upload document. Please try again.');
          return;
        }

        setUploadedDocuments(prev => ({
          ...prev,
          [documentTypeMap[field]]: true
        }));

        showSuccess(`${file.name} uploaded successfully`);
        await loadUploadedDocuments();
      } catch (innerError) {
        console.error('Error in reader.onload:', innerError);
        showError('Failed to upload document. Please try again.');
      }
    };

    reader.onerror = () => {
      console.error('FileReader error');
      showError('Failed to read file. Please try again.');
    };

    reader.readAsDataURL(file);
  };

  const submitSelfieVerification = async () => {
    if (!user) return;
    if (!uploadedDocuments.selfie && !uploadedFiles.selfie) {
      showError('Please upload a selfie photo');
      return;
    }

    setSubmitting(true);
    try {
      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .update({
          kyc_level: 3,
          kyc_status: 'verified',
        })
        .eq('user_id', user.id);

      if (kycError) throw kycError;

      const { error: profileError } = await supabase
        .from('user_profiles')
        .update({
          kyc_status: 'verified',
          kyc_level: 3
        })
        .eq('id', user.id);

      if (profileError) throw profileError;

      await refreshProfile();
      showSuccess('Selfie verification completed! You now have Advanced level access.');
      await loadKYCData();
    } catch (error) {
      console.error('Error submitting selfie:', error);
      showError('Failed to submit selfie. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };



  const savePersonalInfo = async () => {
    if (!user) return;
    if (!formData.firstName || !formData.lastName || !formData.dateOfBirth || !formData.nationality) {
      showError('Please fill in all required fields');
      return;
    }

    setSubmitting(true);
    try {
      const kycData: any = {
        user_id: user.id,
        verification_type: verificationType,
        kyc_level: 1,
        kyc_status: 'verified',
        first_name: formData.firstName,
        last_name: formData.lastName,
        date_of_birth: formData.dateOfBirth,
        nationality: formData.nationality,
      };

      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .upsert(kycData, { onConflict: 'user_id' });

      if (kycError) throw kycError;

      const { error: profileError } = await supabase
        .from('user_profiles')
        .update({
          kyc_status: 'verified',
          kyc_level: 1
        })
        .eq('id', user.id);

      if (profileError) throw profileError;

      await refreshProfile();
      showSuccess('Personal information saved! You now have Basic verification.');
      await loadKYCData();
      setCurrentStep(2);
    } catch (error) {
      console.error('Error saving personal info:', error);
      showError('Failed to save personal information. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const saveAddressInfo = async () => {
    if (!user) return;
    if (!formData.address || !formData.city || !formData.postalCode || !formData.country) {
      showError('Please fill in all required fields');
      return;
    }

    setSubmitting(true);
    try {
      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .update({
          address: formData.address,
          city: formData.city,
          postal_code: formData.postalCode,
          country: formData.country,
        })
        .eq('user_id', user.id);

      if (kycError) throw kycError;

      showSuccess('Address information saved!');
      await loadKYCData();
      setCurrentStep(3);
    } catch (error) {
      console.error('Error saving address info:', error);
      showError('Failed to save address information. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const submitIDVerification = async () => {
    if (!user) return;
    const requiresBack = formData.idType !== 'passport';
    if (!uploadedDocuments.id_front && !uploadedFiles.idFront) {
      showError('Please upload the front of your ID');
      return;
    }
    if (requiresBack && !uploadedDocuments.id_back && !uploadedFiles.idBack) {
      showError('Please upload both front and back of your ID');
      return;
    }

    setSubmitting(true);
    try {
      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .update({
          id_type: formData.idType,
          kyc_level: 2,
          kyc_status: 'pending',
        })
        .eq('user_id', user.id);

      if (kycError) throw kycError;

      const { error: profileError } = await supabase
        .from('user_profiles')
        .update({
          kyc_status: 'pending',
          kyc_level: 1
        })
        .eq('id', user.id);

      if (profileError) throw profileError;

      await refreshProfile();
      showSuccess('ID verification submitted! Your documents are under review. Please proceed to face verification.');
      setCurrentStep(4);
    } catch (error) {
      console.error('Error submitting ID verification:', error);
      showError('Failed to submit ID verification. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const submitFinalVerification = async () => {
    if (!user) return;
    if (!verificationResult || !verificationResult.verificationPassed) {
      showError('Please complete face verification successfully');
      return;
    }

    setSubmitting(true);
    try {
      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .update({
          kyc_level: 3,
          kyc_status: 'pending',
        })
        .eq('user_id', user.id);

      if (kycError) throw kycError;

      const { error: profileError } = await supabase
        .from('user_profiles')
        .update({
          kyc_status: 'pending',
          kyc_level: 2
        })
        .eq('id', user.id);

      if (profileError) throw profileError;

      await refreshProfile();
      showSuccess('Final verification submitted! Your application is under review.');
      await loadKYCData();
    } catch (error) {
      console.error('Error submitting final verification:', error);
      showError('Failed to complete verification. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const submitBusinessInfo = async () => {
    if (!user) return;
    if (!formData.companyName || !formData.companyCountry || !formData.incorporationDate || !formData.businessNature || !formData.taxId) {
      showError('Please fill in all required fields');
      return;
    }

    setSubmitting(true);
    try {
      const kycData: any = {
        user_id: user.id,
        verification_type: verificationType,
        kyc_level: 4,
        kyc_status: 'pending',
        company_name: formData.companyName,
        company_country: formData.companyCountry,
        incorporation_date: formData.incorporationDate,
        business_nature: formData.businessNature,
        tax_id: formData.taxId,
      };

      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .upsert(kycData, { onConflict: 'user_id' });

      if (kycError) throw kycError;

      showSuccess('Business information saved!');
      await loadKYCData();
      setCurrentStep(2);
    } catch (error) {
      console.error('Error saving business info:', error);
      showError('Failed to save business information. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const submitBusinessDocuments = async () => {
    if (!user) return;
    if (!uploadedDocuments.business_doc) {
      showError('Please upload your business documents');
      return;
    }

    setSubmitting(true);
    try {
      const { error: kycError } = await supabase
        .from('kyc_verifications')
        .update({
          kyc_level: 4,
          kyc_status: 'pending',
        })
        .eq('user_id', user.id);

      if (kycError) throw kycError;

      const { error: profileError } = await supabase
        .from('user_profiles')
        .update({
          kyc_status: 'pending',
          kyc_level: 4
        })
        .eq('id', user.id);

      if (profileError) throw profileError;

      await refreshProfile();
      showSuccess('Entity verification submitted! We will review your application within 24-48 hours.');
      await loadKYCData();
    } catch (error) {
      console.error('Error submitting business documents:', error);
      showError('Failed to submit business documents. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const individualSteps = [
    { number: 1, title: 'Personal Info', icon: User },
    { number: 2, title: 'Address', icon: MapPin },
    { number: 3, title: 'ID Verification', icon: CreditCard },
    { number: 4, title: 'Selfie & Face', icon: Camera },
  ];

  const businessSteps = [
    { number: 1, title: 'Business Info', icon: Building2 },
    { number: 2, title: 'Documents', icon: FileText },
  ];

  const steps = verificationType === 'individual' ? individualSteps : businessSteps;

  const benefits = {
    basic: [
      'Submit personal information',
      'Deposit & Trade Crypto',
      'Daily Withdrawal Limit: 2 BTC',
      'Access to Spot Trading',
      'Basic Customer Support',
    ],
    intermediate: [
      'All Basic Features',
      'Submit government-issued ID',
      'Daily Withdrawal Limit: 50 BTC',
      'Access to Advanced Trading',
      'Enhanced Security',
    ],
    advanced: [
      'All Intermediate Features',
      'Selfie & Face verification',
      'Daily Withdrawal Limit: 100 BTC',
      'Futures & Margin Trading',
      'Priority Customer Support',
      'Lower Trading Fees',
      'P2P Trading Access',
    ],
    entity: [
      'All Advanced Features',
      'Full Fiat Services Access',
      'Corporate Trading Account',
      'Unlimited Daily Withdrawals',
      'Dedicated Account Manager',
      'API Access for Businesses',
      'Institutional Trading Features',
    ],
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11] text-white">
        <Navbar />
        <div className="flex items-center justify-center h-[60vh]">
          <div className="animate-spin w-12 h-12 border-4 border-[#f0b90b] border-t-transparent rounded-full"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />
      <ToastContainer toasts={toasts} removeToast={removeToast} />


      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-white mb-2 flex items-center gap-3">
            <Shield className="w-10 h-10 text-[#f0b90b]" />
            KYC Verification
          </h1>
          <p className="text-gray-400">Complete your identity verification to unlock full platform features</p>
        </div>


        {existingKYC && existingKYC.kyc_status === 'verified' && existingKYC.kyc_level >= 1 && (
          <div className="bg-emerald-900/20 border border-emerald-800/30 rounded-xl p-4 mb-6">
            <div className="flex items-center gap-3">
              <CheckCircle2 className="w-6 h-6 text-emerald-400" />
              <div>
                <p className="text-white font-semibold">Verification Level {existingKYC.kyc_level} Verified</p>
                <p className="text-gray-400 text-sm">
                  {existingKYC.kyc_level === 1 && 'You have Basic verification. Continue to unlock more features!'}
                  {existingKYC.kyc_level === 2 && 'You have Intermediate verification. Complete the next step for full access!'}
                  {existingKYC.kyc_level === 3 && 'You have Advanced verification with full platform access!'}
                  {existingKYC.kyc_level === 4 && 'You have Entity verification with institutional features!'}
                </p>
              </div>
            </div>
          </div>
        )}

        {(!existingKYC || (existingKYC.kyc_status !== 'pending' && existingKYC.kyc_level === 0)) && (
          <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6 mb-6">
            <h2 className="text-xl font-bold text-white mb-4">Select Verification Type</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <button
                onClick={() => setVerificationType('individual')}
                className={`p-6 rounded-xl border-2 transition-all text-left ${
                  verificationType === 'individual'
                    ? 'border-[#f0b90b] bg-[#f0b90b]/10'
                    : 'border-gray-700 hover:border-gray-600'
                }`}
              >
                <User className="w-8 h-8 text-[#f0b90b] mb-3" />
                <h3 className="text-lg font-bold text-white mb-2">Individual User</h3>
                <p className="text-gray-400 text-sm">Personal account verification for individual traders</p>
              </button>

              <button
                onClick={() => setVerificationType('business')}
                className={`p-6 rounded-xl border-2 transition-all text-left ${
                  verificationType === 'business'
                    ? 'border-[#f0b90b] bg-[#f0b90b]/10'
                    : 'border-gray-700 hover:border-gray-600'
                }`}
              >
                <Building2 className="w-8 h-8 text-[#f0b90b] mb-3" />
                <h3 className="text-lg font-bold text-white mb-2">Business / Entity</h3>
                <p className="text-gray-400 text-sm">Corporate verification for businesses and institutions</p>
              </button>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
              <div className="flex items-center justify-between mb-8 overflow-x-auto pb-2">
                {steps.map((step, idx) => (
                  <div key={step.number} className="flex items-center flex-1 min-w-[120px]">
                    <div className="flex flex-col items-center flex-1">
                      <div className={`w-12 h-12 rounded-full flex items-center justify-center mb-2 transition-all ${
                        currentStep >= step.number
                          ? 'bg-[#f0b90b] text-black'
                          : 'bg-gray-700 text-gray-400'
                      }`}>
                        <step.icon className="w-6 h-6" />
                      </div>
                      <span className={`text-sm font-semibold text-center ${
                        currentStep >= step.number ? 'text-white' : 'text-gray-500'
                      }`}>
                        {step.title}
                      </span>
                    </div>
                    {idx < steps.length - 1 && (
                      <div className={`h-1 flex-1 mx-2 mb-8 rounded ${
                        currentStep > step.number ? 'bg-[#f0b90b]' : 'bg-gray-700'
                      }`} />
                    )}
                  </div>
                ))}
              </div>

              {verificationType === 'individual' && (
                <>
                  {currentStep === 1 && (
                    <div className="space-y-4">
                      <h2 className="text-2xl font-bold text-white mb-4">Personal Information - Basic Verification</h2>
                      <p className="text-gray-400 mb-4">Enter your personal details to get Basic verification</p>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">First Name *</label>
                          <input
                            type="text"
                            value={formData.firstName}
                            onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                            placeholder="John"
                          />
                        </div>
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">Last Name *</label>
                          <input
                            type="text"
                            value={formData.lastName}
                            onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                            placeholder="Doe"
                          />
                        </div>
                      </div>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">Date of Birth *</label>
                          <input
                            type="date"
                            value={formData.dateOfBirth}
                            onChange={(e) => setFormData({ ...formData, dateOfBirth: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          />
                        </div>
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">Nationality *</label>
                          <select
                            value={formData.nationality}
                            onChange={(e) => setFormData({ ...formData, nationality: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          >
                            <option value="">Select Country</option>
                            <option value="AF">Afghanistan</option>
                            <option value="AL">Albania</option>
                            <option value="DZ">Algeria</option>
                            <option value="AD">Andorra</option>
                            <option value="AO">Angola</option>
                            <option value="AG">Antigua and Barbuda</option>
                            <option value="AR">Argentina</option>
                            <option value="AM">Armenia</option>
                            <option value="AU">Australia</option>
                            <option value="AT">Austria</option>
                            <option value="AZ">Azerbaijan</option>
                            <option value="BS">Bahamas</option>
                            <option value="BH">Bahrain</option>
                            <option value="BD">Bangladesh</option>
                            <option value="BB">Barbados</option>
                            <option value="BY">Belarus</option>
                            <option value="BE">Belgium</option>
                            <option value="BZ">Belize</option>
                            <option value="BJ">Benin</option>
                            <option value="BT">Bhutan</option>
                            <option value="BO">Bolivia</option>
                            <option value="BA">Bosnia and Herzegovina</option>
                            <option value="BW">Botswana</option>
                            <option value="BR">Brazil</option>
                            <option value="BN">Brunei</option>
                            <option value="BG">Bulgaria</option>
                            <option value="BF">Burkina Faso</option>
                            <option value="BI">Burundi</option>
                            <option value="CV">Cabo Verde</option>
                            <option value="KH">Cambodia</option>
                            <option value="CM">Cameroon</option>
                            <option value="CA">Canada</option>
                            <option value="CF">Central African Republic</option>
                            <option value="TD">Chad</option>
                            <option value="CL">Chile</option>
                            <option value="CN">China</option>
                            <option value="CO">Colombia</option>
                            <option value="KM">Comoros</option>
                            <option value="CG">Congo</option>
                            <option value="CR">Costa Rica</option>
                            <option value="HR">Croatia</option>
                            <option value="CU">Cuba</option>
                            <option value="CY">Cyprus</option>
                            <option value="CZ">Czech Republic</option>
                            <option value="DK">Denmark</option>
                            <option value="DJ">Djibouti</option>
                            <option value="DM">Dominica</option>
                            <option value="DO">Dominican Republic</option>
                            <option value="EC">Ecuador</option>
                            <option value="EG">Egypt</option>
                            <option value="SV">El Salvador</option>
                            <option value="GQ">Equatorial Guinea</option>
                            <option value="ER">Eritrea</option>
                            <option value="EE">Estonia</option>
                            <option value="SZ">Eswatini</option>
                            <option value="ET">Ethiopia</option>
                            <option value="FJ">Fiji</option>
                            <option value="FI">Finland</option>
                            <option value="FR">France</option>
                            <option value="GA">Gabon</option>
                            <option value="GM">Gambia</option>
                            <option value="GE">Georgia</option>
                            <option value="DE">Germany</option>
                            <option value="GH">Ghana</option>
                            <option value="GR">Greece</option>
                            <option value="GD">Grenada</option>
                            <option value="GT">Guatemala</option>
                            <option value="GN">Guinea</option>
                            <option value="GW">Guinea-Bissau</option>
                            <option value="GY">Guyana</option>
                            <option value="HT">Haiti</option>
                            <option value="HN">Honduras</option>
                            <option value="HU">Hungary</option>
                            <option value="IS">Iceland</option>
                            <option value="IN">India</option>
                            <option value="ID">Indonesia</option>
                            <option value="IR">Iran</option>
                            <option value="IQ">Iraq</option>
                            <option value="IE">Ireland</option>
                            <option value="IL">Israel</option>
                            <option value="IT">Italy</option>
                            <option value="JM">Jamaica</option>
                            <option value="JP">Japan</option>
                            <option value="JO">Jordan</option>
                            <option value="KZ">Kazakhstan</option>
                            <option value="KE">Kenya</option>
                            <option value="KI">Kiribati</option>
                            <option value="KP">Korea (North)</option>
                            <option value="KR">Korea (South)</option>
                            <option value="KW">Kuwait</option>
                            <option value="KG">Kyrgyzstan</option>
                            <option value="LA">Laos</option>
                            <option value="LV">Latvia</option>
                            <option value="LB">Lebanon</option>
                            <option value="LS">Lesotho</option>
                            <option value="LR">Liberia</option>
                            <option value="LY">Libya</option>
                            <option value="LI">Liechtenstein</option>
                            <option value="LT">Lithuania</option>
                            <option value="LU">Luxembourg</option>
                            <option value="MG">Madagascar</option>
                            <option value="MW">Malawi</option>
                            <option value="MY">Malaysia</option>
                            <option value="MV">Maldives</option>
                            <option value="ML">Mali</option>
                            <option value="MT">Malta</option>
                            <option value="MH">Marshall Islands</option>
                            <option value="MR">Mauritania</option>
                            <option value="MU">Mauritius</option>
                            <option value="MX">Mexico</option>
                            <option value="FM">Micronesia</option>
                            <option value="MD">Moldova</option>
                            <option value="MC">Monaco</option>
                            <option value="MN">Mongolia</option>
                            <option value="ME">Montenegro</option>
                            <option value="MA">Morocco</option>
                            <option value="MZ">Mozambique</option>
                            <option value="MM">Myanmar</option>
                            <option value="NA">Namibia</option>
                            <option value="NR">Nauru</option>
                            <option value="NP">Nepal</option>
                            <option value="NL">Netherlands</option>
                            <option value="NZ">New Zealand</option>
                            <option value="NI">Nicaragua</option>
                            <option value="NE">Niger</option>
                            <option value="NG">Nigeria</option>
                            <option value="MK">North Macedonia</option>
                            <option value="NO">Norway</option>
                            <option value="OM">Oman</option>
                            <option value="PK">Pakistan</option>
                            <option value="PW">Palau</option>
                            <option value="PA">Panama</option>
                            <option value="PG">Papua New Guinea</option>
                            <option value="PY">Paraguay</option>
                            <option value="PE">Peru</option>
                            <option value="PH">Philippines</option>
                            <option value="PL">Poland</option>
                            <option value="PT">Portugal</option>
                            <option value="QA">Qatar</option>
                            <option value="RO">Romania</option>
                            <option value="RU">Russia</option>
                            <option value="RW">Rwanda</option>
                            <option value="KN">Saint Kitts and Nevis</option>
                            <option value="LC">Saint Lucia</option>
                            <option value="VC">Saint Vincent and the Grenadines</option>
                            <option value="WS">Samoa</option>
                            <option value="SM">San Marino</option>
                            <option value="ST">Sao Tome and Principe</option>
                            <option value="SA">Saudi Arabia</option>
                            <option value="SN">Senegal</option>
                            <option value="RS">Serbia</option>
                            <option value="SC">Seychelles</option>
                            <option value="SL">Sierra Leone</option>
                            <option value="SG">Singapore</option>
                            <option value="SK">Slovakia</option>
                            <option value="SI">Slovenia</option>
                            <option value="SB">Solomon Islands</option>
                            <option value="SO">Somalia</option>
                            <option value="ZA">South Africa</option>
                            <option value="SS">South Sudan</option>
                            <option value="ES">Spain</option>
                            <option value="LK">Sri Lanka</option>
                            <option value="SD">Sudan</option>
                            <option value="SR">Suriname</option>
                            <option value="SE">Sweden</option>
                            <option value="CH">Switzerland</option>
                            <option value="SY">Syria</option>
                            <option value="TW">Taiwan</option>
                            <option value="TJ">Tajikistan</option>
                            <option value="TZ">Tanzania</option>
                            <option value="TH">Thailand</option>
                            <option value="TL">Timor-Leste</option>
                            <option value="TG">Togo</option>
                            <option value="TO">Tonga</option>
                            <option value="TT">Trinidad and Tobago</option>
                            <option value="TN">Tunisia</option>
                            <option value="TR">Turkey</option>
                            <option value="TM">Turkmenistan</option>
                            <option value="TV">Tuvalu</option>
                            <option value="UG">Uganda</option>
                            <option value="UA">Ukraine</option>
                            <option value="AE">United Arab Emirates</option>
                            <option value="GB">United Kingdom</option>
                            <option value="US">United States</option>
                            <option value="UY">Uruguay</option>
                            <option value="UZ">Uzbekistan</option>
                            <option value="VU">Vanuatu</option>
                            <option value="VA">Vatican City</option>
                            <option value="VE">Venezuela</option>
                            <option value="VN">Vietnam</option>
                            <option value="YE">Yemen</option>
                            <option value="ZM">Zambia</option>
                            <option value="ZW">Zimbabwe</option>
                          </select>
                        </div>
                      </div>
                      <div className="flex gap-4 mt-8">
                        <button
                          onClick={savePersonalInfo}
                          disabled={submitting}
                          className="flex-1 px-8 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {submitting ? 'Saving...' : 'Save & Get Basic Verification'}
                        </button>
                      </div>
                    </div>
                  )}

                  {currentStep === 2 && (
                    <div className="space-y-4">
                      <h2 className="text-2xl font-bold text-white mb-4">Address Information</h2>
                      <p className="text-gray-400 mb-4">Provide your residential address details</p>
                      <div>
                        <label className="block text-gray-400 text-sm mb-2">Street Address *</label>
                        <input
                          type="text"
                          value={formData.address}
                          onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                          className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          placeholder="123 Main Street"
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">City *</label>
                          <input
                            type="text"
                            value={formData.city}
                            onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                            placeholder="New York"
                          />
                        </div>
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">Postal Code *</label>
                          <input
                            type="text"
                            value={formData.postalCode}
                            onChange={(e) => setFormData({ ...formData, postalCode: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                            placeholder="10001"
                          />
                        </div>
                      </div>
                      <div>
                        <label className="block text-gray-400 text-sm mb-2">Country *</label>
                        <select
                          value={formData.country}
                          onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                          className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                        >
                          <option value="">Select Country</option>
                          <option value="AF">Afghanistan</option>
                          <option value="AL">Albania</option>
                          <option value="DZ">Algeria</option>
                          <option value="AD">Andorra</option>
                          <option value="AO">Angola</option>
                          <option value="AG">Antigua and Barbuda</option>
                          <option value="AR">Argentina</option>
                          <option value="AM">Armenia</option>
                          <option value="AU">Australia</option>
                          <option value="AT">Austria</option>
                          <option value="AZ">Azerbaijan</option>
                          <option value="BS">Bahamas</option>
                          <option value="BH">Bahrain</option>
                          <option value="BD">Bangladesh</option>
                          <option value="BB">Barbados</option>
                          <option value="BY">Belarus</option>
                          <option value="BE">Belgium</option>
                          <option value="BZ">Belize</option>
                          <option value="BJ">Benin</option>
                          <option value="BT">Bhutan</option>
                          <option value="BO">Bolivia</option>
                          <option value="BA">Bosnia and Herzegovina</option>
                          <option value="BW">Botswana</option>
                          <option value="BR">Brazil</option>
                          <option value="BN">Brunei</option>
                          <option value="BG">Bulgaria</option>
                          <option value="BF">Burkina Faso</option>
                          <option value="BI">Burundi</option>
                          <option value="CV">Cabo Verde</option>
                          <option value="KH">Cambodia</option>
                          <option value="CM">Cameroon</option>
                          <option value="CA">Canada</option>
                          <option value="CF">Central African Republic</option>
                          <option value="TD">Chad</option>
                          <option value="CL">Chile</option>
                          <option value="CN">China</option>
                          <option value="CO">Colombia</option>
                          <option value="KM">Comoros</option>
                          <option value="CG">Congo</option>
                          <option value="CR">Costa Rica</option>
                          <option value="HR">Croatia</option>
                          <option value="CU">Cuba</option>
                          <option value="CY">Cyprus</option>
                          <option value="CZ">Czech Republic</option>
                          <option value="DK">Denmark</option>
                          <option value="DJ">Djibouti</option>
                          <option value="DM">Dominica</option>
                          <option value="DO">Dominican Republic</option>
                          <option value="EC">Ecuador</option>
                          <option value="EG">Egypt</option>
                          <option value="SV">El Salvador</option>
                          <option value="GQ">Equatorial Guinea</option>
                          <option value="ER">Eritrea</option>
                          <option value="EE">Estonia</option>
                          <option value="SZ">Eswatini</option>
                          <option value="ET">Ethiopia</option>
                          <option value="FJ">Fiji</option>
                          <option value="FI">Finland</option>
                          <option value="FR">France</option>
                          <option value="GA">Gabon</option>
                          <option value="GM">Gambia</option>
                          <option value="GE">Georgia</option>
                          <option value="DE">Germany</option>
                          <option value="GH">Ghana</option>
                          <option value="GR">Greece</option>
                          <option value="GD">Grenada</option>
                          <option value="GT">Guatemala</option>
                          <option value="GN">Guinea</option>
                          <option value="GW">Guinea-Bissau</option>
                          <option value="GY">Guyana</option>
                          <option value="HT">Haiti</option>
                          <option value="HN">Honduras</option>
                          <option value="HU">Hungary</option>
                          <option value="IS">Iceland</option>
                          <option value="IN">India</option>
                          <option value="ID">Indonesia</option>
                          <option value="IR">Iran</option>
                          <option value="IQ">Iraq</option>
                          <option value="IE">Ireland</option>
                          <option value="IL">Israel</option>
                          <option value="IT">Italy</option>
                          <option value="JM">Jamaica</option>
                          <option value="JP">Japan</option>
                          <option value="JO">Jordan</option>
                          <option value="KZ">Kazakhstan</option>
                          <option value="KE">Kenya</option>
                          <option value="KI">Kiribati</option>
                          <option value="KP">Korea (North)</option>
                          <option value="KR">Korea (South)</option>
                          <option value="KW">Kuwait</option>
                          <option value="KG">Kyrgyzstan</option>
                          <option value="LA">Laos</option>
                          <option value="LV">Latvia</option>
                          <option value="LB">Lebanon</option>
                          <option value="LS">Lesotho</option>
                          <option value="LR">Liberia</option>
                          <option value="LY">Libya</option>
                          <option value="LI">Liechtenstein</option>
                          <option value="LT">Lithuania</option>
                          <option value="LU">Luxembourg</option>
                          <option value="MG">Madagascar</option>
                          <option value="MW">Malawi</option>
                          <option value="MY">Malaysia</option>
                          <option value="MV">Maldives</option>
                          <option value="ML">Mali</option>
                          <option value="MT">Malta</option>
                          <option value="MH">Marshall Islands</option>
                          <option value="MR">Mauritania</option>
                          <option value="MU">Mauritius</option>
                          <option value="MX">Mexico</option>
                          <option value="FM">Micronesia</option>
                          <option value="MD">Moldova</option>
                          <option value="MC">Monaco</option>
                          <option value="MN">Mongolia</option>
                          <option value="ME">Montenegro</option>
                          <option value="MA">Morocco</option>
                          <option value="MZ">Mozambique</option>
                          <option value="MM">Myanmar</option>
                          <option value="NA">Namibia</option>
                          <option value="NR">Nauru</option>
                          <option value="NP">Nepal</option>
                          <option value="NL">Netherlands</option>
                          <option value="NZ">New Zealand</option>
                          <option value="NI">Nicaragua</option>
                          <option value="NE">Niger</option>
                          <option value="NG">Nigeria</option>
                          <option value="MK">North Macedonia</option>
                          <option value="NO">Norway</option>
                          <option value="OM">Oman</option>
                          <option value="PK">Pakistan</option>
                          <option value="PW">Palau</option>
                          <option value="PA">Panama</option>
                          <option value="PG">Papua New Guinea</option>
                          <option value="PY">Paraguay</option>
                          <option value="PE">Peru</option>
                          <option value="PH">Philippines</option>
                          <option value="PL">Poland</option>
                          <option value="PT">Portugal</option>
                          <option value="QA">Qatar</option>
                          <option value="RO">Romania</option>
                          <option value="RU">Russia</option>
                          <option value="RW">Rwanda</option>
                          <option value="KN">Saint Kitts and Nevis</option>
                          <option value="LC">Saint Lucia</option>
                          <option value="VC">Saint Vincent and the Grenadines</option>
                          <option value="WS">Samoa</option>
                          <option value="SM">San Marino</option>
                          <option value="ST">Sao Tome and Principe</option>
                          <option value="SA">Saudi Arabia</option>
                          <option value="SN">Senegal</option>
                          <option value="RS">Serbia</option>
                          <option value="SC">Seychelles</option>
                          <option value="SL">Sierra Leone</option>
                          <option value="SG">Singapore</option>
                          <option value="SK">Slovakia</option>
                          <option value="SI">Slovenia</option>
                          <option value="SB">Solomon Islands</option>
                          <option value="SO">Somalia</option>
                          <option value="ZA">South Africa</option>
                          <option value="SS">South Sudan</option>
                          <option value="ES">Spain</option>
                          <option value="LK">Sri Lanka</option>
                          <option value="SD">Sudan</option>
                          <option value="SR">Suriname</option>
                          <option value="SE">Sweden</option>
                          <option value="CH">Switzerland</option>
                          <option value="SY">Syria</option>
                          <option value="TW">Taiwan</option>
                          <option value="TJ">Tajikistan</option>
                          <option value="TZ">Tanzania</option>
                          <option value="TH">Thailand</option>
                          <option value="TL">Timor-Leste</option>
                          <option value="TG">Togo</option>
                          <option value="TO">Tonga</option>
                          <option value="TT">Trinidad and Tobago</option>
                          <option value="TN">Tunisia</option>
                          <option value="TR">Turkey</option>
                          <option value="TM">Turkmenistan</option>
                          <option value="TV">Tuvalu</option>
                          <option value="UG">Uganda</option>
                          <option value="UA">Ukraine</option>
                          <option value="AE">United Arab Emirates</option>
                          <option value="GB">United Kingdom</option>
                          <option value="US">United States</option>
                          <option value="UY">Uruguay</option>
                          <option value="UZ">Uzbekistan</option>
                          <option value="VU">Vanuatu</option>
                          <option value="VA">Vatican City</option>
                          <option value="VE">Venezuela</option>
                          <option value="VN">Vietnam</option>
                          <option value="YE">Yemen</option>
                          <option value="ZM">Zambia</option>
                          <option value="ZW">Zimbabwe</option>
                        </select>
                      </div>
                      <div className="flex gap-4 mt-8">
                        <button
                          onClick={() => setCurrentStep(1)}
                          disabled={submitting}
                          className="px-8 py-3 bg-[#0b0e11] border border-gray-700 hover:border-gray-600 text-white font-semibold rounded-xl transition-all disabled:opacity-50"
                        >
                          Back
                        </button>
                        <button
                          onClick={saveAddressInfo}
                          disabled={submitting}
                          className="flex-1 px-8 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {submitting ? 'Saving...' : 'Save & Continue'}
                        </button>
                      </div>
                    </div>
                  )}

                  {currentStep === 3 && (
                    <div className="space-y-4">
                      <h2 className="text-2xl font-bold text-white mb-4">ID Verification - Intermediate Level</h2>
                      <p className="text-gray-400 mb-4">Upload your government-issued ID to get Intermediate verification</p>

                      {existingKYC && existingKYC.kyc_status === 'pending' && existingKYC.kyc_level >= 2 && (
                        <div className="bg-gradient-to-r from-yellow-900/30 to-yellow-800/20 border border-yellow-600/40 rounded-xl p-5 mb-4">
                          <div className="flex items-start gap-4">
                            <div className="bg-yellow-500/20 p-2.5 rounded-lg">
                              <AlertCircle className="w-6 h-6 text-yellow-400" />
                            </div>
                            <div className="flex-1">
                              <p className="text-white font-bold text-base mb-1.5">Documents Under Review</p>
                              <p className="text-gray-300 text-sm mb-2">
                                Your ID documents have been submitted and are being reviewed by our verification team.
                              </p>
                              <p className="text-gray-400 text-xs">
                                Verification typically takes 24-48 hours. You'll be notified once complete.
                              </p>
                            </div>
                          </div>
                        </div>
                      )}

                      <div>
                        <label className="block text-gray-400 text-sm mb-2">ID Type *</label>
                        <select
                          value={formData.idType}
                          onChange={(e) => setFormData({ ...formData, idType: e.target.value })}
                          disabled={existingKYC?.kyc_status === 'pending' && existingKYC?.kyc_level >= 2}
                          className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <option value="passport">Passport</option>
                          <option value="drivers-license">Driver's License</option>
                          <option value="national-id">National ID Card</option>
                        </select>
                      </div>

                      <div className={`grid ${formData.idType === 'passport' ? 'grid-cols-1' : 'grid-cols-2'} gap-4 mt-6`}>
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">
                            Upload ID Front * {uploadedDocuments.id_front && <span className="text-emerald-400">✓ Uploaded</span>}
                          </label>
                          {existingKYC && existingKYC.kyc_status === 'pending' && existingKYC.kyc_level >= 2 ? (
                            <div className="border-2 border-yellow-800/30 bg-yellow-900/10 rounded-xl p-8 text-center">
                              <AlertCircle className="w-12 h-12 text-yellow-400 mx-auto mb-3" />
                              <p className="text-yellow-400 text-sm font-semibold mb-1">Pending Review</p>
                              <p className="text-gray-500 text-xs">Document submitted</p>
                            </div>
                          ) : (
                            <div className={`border-2 border-dashed rounded-xl p-8 text-center transition-colors cursor-pointer ${
                              uploadedDocuments.id_front || uploadedFiles.idFront
                                ? 'border-green-500 bg-green-500/10 hover:border-green-400'
                                : 'border-gray-700 hover:border-[#f0b90b]'
                            }`}>
                              <input
                                type="file"
                                accept="image/*"
                                onChange={(e) => handleFileUpload('idFront', e)}
                                className="hidden"
                                id="idFront"
                              />
                              <label htmlFor="idFront" className="cursor-pointer">
                                {uploadedDocuments.id_front || uploadedFiles.idFront ? (
                                  <CheckCircle2 className="w-12 h-12 text-green-400 mx-auto mb-3" />
                                ) : (
                                  <Upload className="w-12 h-12 text-gray-400 mx-auto mb-3" />
                                )}
                                <p className={`text-sm mb-1 ${uploadedDocuments.id_front || uploadedFiles.idFront ? 'text-green-400 font-medium' : 'text-gray-400'}`}>
                                  {uploadedDocuments.id_front || uploadedFiles.idFront ? '✓ Uploaded Successfully' : 'Click to upload'}
                                </p>
                                <p className="text-gray-500 text-xs">JPG, PNG up to 10MB</p>
                              </label>
                            </div>
                          )}
                        </div>
                        {formData.idType !== 'passport' && (
                          <div>
                            <label className="block text-gray-400 text-sm mb-2">
                              Upload ID Back * {uploadedDocuments.id_back && <span className="text-emerald-400">✓ Uploaded</span>}
                            </label>
                            {existingKYC && existingKYC.kyc_status === 'pending' && existingKYC.kyc_level >= 2 ? (
                              <div className="border-2 border-yellow-800/30 bg-yellow-900/10 rounded-xl p-8 text-center">
                                <AlertCircle className="w-12 h-12 text-yellow-400 mx-auto mb-3" />
                                <p className="text-yellow-400 text-sm font-semibold mb-1">Pending Review</p>
                                <p className="text-gray-500 text-xs">Document submitted</p>
                              </div>
                            ) : (
                              <div className={`border-2 border-dashed rounded-xl p-8 text-center transition-colors cursor-pointer ${
                                uploadedDocuments.id_back || uploadedFiles.idBack
                                  ? 'border-green-500 bg-green-500/10 hover:border-green-400'
                                  : 'border-gray-700 hover:border-[#f0b90b]'
                              }`}>
                                <input
                                  type="file"
                                  accept="image/*"
                                  onChange={(e) => handleFileUpload('idBack', e)}
                                  className="hidden"
                                  id="idBack"
                                />
                                <label htmlFor="idBack" className="cursor-pointer">
                                  {uploadedDocuments.id_back || uploadedFiles.idBack ? (
                                    <CheckCircle2 className="w-12 h-12 text-green-400 mx-auto mb-3" />
                                  ) : (
                                    <Upload className="w-12 h-12 text-gray-400 mx-auto mb-3" />
                                  )}
                                  <p className={`text-sm mb-1 ${uploadedDocuments.id_back || uploadedFiles.idBack ? 'text-green-400 font-medium' : 'text-gray-400'}`}>
                                    {uploadedDocuments.id_back || uploadedFiles.idBack ? '✓ Uploaded Successfully' : 'Click to upload'}
                                  </p>
                                  <p className="text-gray-500 text-xs">JPG, PNG up to 10MB</p>
                                </label>
                              </div>
                            )}
                          </div>
                        )}
                      </div>

                      <div className="bg-blue-900/20 border border-blue-800/30 rounded-xl p-4 mt-4">
                        <div className="flex items-start gap-3">
                          <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                          <div className="text-sm text-gray-300">
                            <p className="font-semibold text-white mb-1">Document Requirements:</p>
                            <ul className="space-y-1 list-disc list-inside">
                              <li>Document must be valid and not expired</li>
                              <li>All corners of the document must be visible</li>
                              <li>All information must be clearly readable</li>
                              <li>No glare or shadows on the document</li>
                            </ul>
                          </div>
                        </div>
                      </div>

                      <div className="flex gap-4 mt-8">
                        <button
                          onClick={() => setCurrentStep(2)}
                          disabled={submitting || (existingKYC?.kyc_status === 'pending' && existingKYC?.kyc_level >= 2)}
                          className="px-8 py-3 bg-[#0b0e11] border border-gray-700 hover:border-gray-600 text-white font-semibold rounded-xl transition-all disabled:opacity-50"
                        >
                          Back
                        </button>
                        <button
                          onClick={submitIDVerification}
                          disabled={submitting || (existingKYC?.kyc_status === 'pending' && existingKYC?.kyc_level >= 2)}
                          className="flex-1 px-8 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {existingKYC?.kyc_status === 'pending' && existingKYC?.kyc_level >= 2
                            ? 'Submitted - Awaiting Review'
                            : submitting ? 'Submitting...' : 'Submit & Get Intermediate Verification'
                          }
                        </button>
                      </div>
                    </div>
                  )}

                  {currentStep === 4 && (
                    <div className="space-y-4">
                      <h2 className="text-2xl font-bold text-white mb-4">Selfie Verification - Advanced Level</h2>
                      <p className="text-gray-400 mb-6">Upload a clear selfie photo to complete your identity verification</p>

                      {existingKYC && existingKYC.kyc_status === 'verified' && existingKYC.kyc_level >= 3 && (
                        <div className="bg-gradient-to-r from-emerald-900/30 to-emerald-800/20 border border-emerald-600/40 rounded-xl p-5 mb-4">
                          <div className="flex items-start gap-4">
                            <div className="bg-emerald-500/20 p-2.5 rounded-lg">
                              <CheckCircle2 className="w-6 h-6 text-emerald-400" />
                            </div>
                            <div className="flex-1">
                              <p className="text-white font-bold text-base mb-1.5">Face Verification Complete!</p>
                              <p className="text-gray-300 text-sm mb-2">
                                Your selfie has been verified successfully. You now have Advanced level access with full platform features.
                              </p>
                              <p className="text-gray-400 text-xs">
                                All verification requirements have been met.
                              </p>
                            </div>
                          </div>
                        </div>
                      )}

                      {existingKYC && existingKYC.kyc_status === 'pending' && existingKYC.kyc_level >= 3 && (
                        <div className="bg-gradient-to-r from-yellow-900/30 to-yellow-800/20 border border-yellow-600/40 rounded-xl p-5 mb-4">
                          <div className="flex items-start gap-4">
                            <div className="bg-yellow-500/20 p-2.5 rounded-lg">
                              <AlertCircle className="w-6 h-6 text-yellow-400" />
                            </div>
                            <div className="flex-1">
                              <p className="text-white font-bold text-base mb-1.5">Selfie Verification Under Review</p>
                              <p className="text-gray-300 text-sm mb-2">
                                Your selfie has been submitted and is being reviewed by our verification team.
                              </p>
                              <p className="text-gray-400 text-xs">
                                Verification typically takes 24-48 hours. You'll be notified once complete.
                              </p>
                            </div>
                          </div>
                        </div>
                      )}

                      {(existingKYC && existingKYC.kyc_level >= 3 && (existingKYC.kyc_status === 'verified' || existingKYC.kyc_status === 'pending')) && (
                        <div className="flex gap-4 mt-8">
                          <button
                            onClick={() => setCurrentStep(3)}
                            className="px-8 py-3 bg-[#0b0e11] border border-gray-700 hover:border-gray-600 text-white font-semibold rounded-xl transition-all"
                          >
                            Back to ID Verification
                          </button>
                        </div>
                      )}

                      {!(existingKYC && existingKYC.kyc_level >= 3 && (existingKYC.kyc_status === 'verified' || existingKYC.kyc_status === 'pending')) && (
                        <>
                          <div className="bg-gradient-to-r from-[#f0b90b]/10 to-[#f8d12f]/10 border border-[#f0b90b]/30 rounded-xl p-6">
                            <div className="flex items-start gap-4">
                              <Camera className="w-8 h-8 text-[#f0b90b] flex-shrink-0 mt-1" />
                              <div className="flex-1">
                                <h3 className="text-lg font-bold text-white mb-2">Upload Selfie Photo</h3>
                                <p className="text-gray-300 text-sm mb-4">
                                  Take a clear selfie photo holding your ID document next to your face. Make sure both your face and ID are clearly visible.
                                </p>

                                <ul className="space-y-2 mb-6 text-sm text-gray-400">
                                  <li className="flex items-center gap-2">
                                    <CheckCircle2 className="w-4 h-4 text-[#f0b90b]" />
                                    Hold your ID document next to your face
                                  </li>
                                  <li className="flex items-center gap-2">
                                    <CheckCircle2 className="w-4 h-4 text-[#f0b90b]" />
                                    Ensure good lighting and clear visibility
                                  </li>
                                  <li className="flex items-center gap-2">
                                    <CheckCircle2 className="w-4 h-4 text-[#f0b90b]" />
                                    Face and ID must be in the same photo
                                  </li>
                                  <li className="flex items-center gap-2">
                                    <CheckCircle2 className="w-4 h-4 text-[#f0b90b]" />
                                    File must be JPG, PNG or PDF (max 10MB)
                                  </li>
                                </ul>

                                <div className="space-y-4">
                                  <div className="border-2 border-dashed border-gray-700 rounded-xl p-8 hover:border-[#f0b90b] transition-colors bg-[#0b0e11]">
                                    <input
                                      type="file"
                                      id="selfie-upload"
                                      accept="image/*"
                                      onChange={(e) => handleFileUpload('selfie', e)}
                                      className="hidden"
                                    />
                                    <label htmlFor="selfie-upload" className="cursor-pointer flex flex-col items-center">
                                      <Upload className="w-12 h-12 text-gray-400 mb-3" />
                                      <span className="text-white font-semibold mb-1">
                                        {uploadedFiles.selfie || uploadedDocuments.selfie ? 'Change Selfie' : 'Upload Selfie'}
                                      </span>
                                      <span className="text-gray-400 text-sm">Click to select file</span>
                                      {(uploadedFiles.selfie || uploadedDocuments.selfie) && (
                                        <div className="mt-3 flex items-center gap-2 text-emerald-400">
                                          <CheckCircle2 className="w-5 h-5" />
                                          <span className="text-sm font-semibold">
                                            {uploadedFiles.selfie ? uploadedFiles.selfie.name : 'Selfie uploaded'}
                                          </span>
                                        </div>
                                      )}
                                    </label>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>

                          <div className="bg-blue-900/20 border border-blue-800/30 rounded-xl p-4">
                            <div className="flex items-start gap-3">
                              <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                              <div className="text-sm text-gray-300">
                                <p className="font-semibold text-white mb-1">Selfie Requirements:</p>
                                <ul className="space-y-1 list-disc list-inside">
                                  <li>Hold your ID document next to your face</li>
                                  <li>Ensure both face and ID are clearly visible</li>
                                  <li>Use good lighting without glare or shadows</li>
                                  <li>Face the camera directly</li>
                                  <li>Remove sunglasses or anything covering your face</li>
                                </ul>
                              </div>
                            </div>
                          </div>

                          <div className="flex gap-4 mt-8">
                            <button
                              onClick={() => setCurrentStep(3)}
                              disabled={submitting}
                              className="px-8 py-3 bg-[#0b0e11] border border-gray-700 hover:border-gray-600 text-white font-semibold rounded-xl transition-all disabled:opacity-50"
                            >
                              Back
                            </button>
                            <button
                              onClick={submitSelfieVerification}
                              disabled={submitting || (!uploadedFiles.selfie && !uploadedDocuments.selfie)}
                              className="flex-1 px-8 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                              {submitting ? 'Submitting...' : 'Submit for Verification'}
                            </button>
                          </div>
                        </>
                      )}
                    </div>
                  )}
                </>
              )}

              {verificationType === 'business' && (
                <>
                  {currentStep === 1 && (
                    <div className="space-y-4">
                      <h2 className="text-2xl font-bold text-white mb-4">Business Information - Entity Verification</h2>
                      <p className="text-gray-400 mb-4">Provide your company details for entity verification</p>

                      <div>
                        <label className="block text-gray-400 text-sm mb-2">Company Name *</label>
                        <input
                          type="text"
                          value={formData.companyName}
                          onChange={(e) => setFormData({ ...formData, companyName: e.target.value })}
                          className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          placeholder="Acme Corporation"
                        />
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">Country of Registration *</label>
                          <select
                            value={formData.companyCountry}
                            onChange={(e) => setFormData({ ...formData, companyCountry: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          >
                            <option value="">Select Country</option>
                            <option value="AF">Afghanistan</option>
                            <option value="AL">Albania</option>
                            <option value="DZ">Algeria</option>
                            <option value="AD">Andorra</option>
                            <option value="AO">Angola</option>
                            <option value="AG">Antigua and Barbuda</option>
                            <option value="AR">Argentina</option>
                            <option value="AM">Armenia</option>
                            <option value="AU">Australia</option>
                            <option value="AT">Austria</option>
                            <option value="AZ">Azerbaijan</option>
                            <option value="BS">Bahamas</option>
                            <option value="BH">Bahrain</option>
                            <option value="BD">Bangladesh</option>
                            <option value="BB">Barbados</option>
                            <option value="BY">Belarus</option>
                            <option value="BE">Belgium</option>
                            <option value="BZ">Belize</option>
                            <option value="BJ">Benin</option>
                            <option value="BT">Bhutan</option>
                            <option value="BO">Bolivia</option>
                            <option value="BA">Bosnia and Herzegovina</option>
                            <option value="BW">Botswana</option>
                            <option value="BR">Brazil</option>
                            <option value="BN">Brunei</option>
                            <option value="BG">Bulgaria</option>
                            <option value="BF">Burkina Faso</option>
                            <option value="BI">Burundi</option>
                            <option value="CV">Cabo Verde</option>
                            <option value="KH">Cambodia</option>
                            <option value="CM">Cameroon</option>
                            <option value="CA">Canada</option>
                            <option value="CF">Central African Republic</option>
                            <option value="TD">Chad</option>
                            <option value="CL">Chile</option>
                            <option value="CN">China</option>
                            <option value="CO">Colombia</option>
                            <option value="KM">Comoros</option>
                            <option value="CG">Congo</option>
                            <option value="CR">Costa Rica</option>
                            <option value="HR">Croatia</option>
                            <option value="CU">Cuba</option>
                            <option value="CY">Cyprus</option>
                            <option value="CZ">Czech Republic</option>
                            <option value="DK">Denmark</option>
                            <option value="DJ">Djibouti</option>
                            <option value="DM">Dominica</option>
                            <option value="DO">Dominican Republic</option>
                            <option value="EC">Ecuador</option>
                            <option value="EG">Egypt</option>
                            <option value="SV">El Salvador</option>
                            <option value="GQ">Equatorial Guinea</option>
                            <option value="ER">Eritrea</option>
                            <option value="EE">Estonia</option>
                            <option value="SZ">Eswatini</option>
                            <option value="ET">Ethiopia</option>
                            <option value="FJ">Fiji</option>
                            <option value="FI">Finland</option>
                            <option value="FR">France</option>
                            <option value="GA">Gabon</option>
                            <option value="GM">Gambia</option>
                            <option value="GE">Georgia</option>
                            <option value="DE">Germany</option>
                            <option value="GH">Ghana</option>
                            <option value="GR">Greece</option>
                            <option value="GD">Grenada</option>
                            <option value="GT">Guatemala</option>
                            <option value="GN">Guinea</option>
                            <option value="GW">Guinea-Bissau</option>
                            <option value="GY">Guyana</option>
                            <option value="HT">Haiti</option>
                            <option value="HN">Honduras</option>
                            <option value="HK">Hong Kong</option>
                            <option value="HU">Hungary</option>
                            <option value="IS">Iceland</option>
                            <option value="IN">India</option>
                            <option value="ID">Indonesia</option>
                            <option value="IR">Iran</option>
                            <option value="IQ">Iraq</option>
                            <option value="IE">Ireland</option>
                            <option value="IL">Israel</option>
                            <option value="IT">Italy</option>
                            <option value="JM">Jamaica</option>
                            <option value="JP">Japan</option>
                            <option value="JO">Jordan</option>
                            <option value="KZ">Kazakhstan</option>
                            <option value="KE">Kenya</option>
                            <option value="KI">Kiribati</option>
                            <option value="KP">Korea (North)</option>
                            <option value="KR">Korea (South)</option>
                            <option value="KW">Kuwait</option>
                            <option value="KG">Kyrgyzstan</option>
                            <option value="LA">Laos</option>
                            <option value="LV">Latvia</option>
                            <option value="LB">Lebanon</option>
                            <option value="LS">Lesotho</option>
                            <option value="LR">Liberia</option>
                            <option value="LY">Libya</option>
                            <option value="LI">Liechtenstein</option>
                            <option value="LT">Lithuania</option>
                            <option value="LU">Luxembourg</option>
                            <option value="MG">Madagascar</option>
                            <option value="MW">Malawi</option>
                            <option value="MY">Malaysia</option>
                            <option value="MV">Maldives</option>
                            <option value="ML">Mali</option>
                            <option value="MT">Malta</option>
                            <option value="MH">Marshall Islands</option>
                            <option value="MR">Mauritania</option>
                            <option value="MU">Mauritius</option>
                            <option value="MX">Mexico</option>
                            <option value="FM">Micronesia</option>
                            <option value="MD">Moldova</option>
                            <option value="MC">Monaco</option>
                            <option value="MN">Mongolia</option>
                            <option value="ME">Montenegro</option>
                            <option value="MA">Morocco</option>
                            <option value="MZ">Mozambique</option>
                            <option value="MM">Myanmar</option>
                            <option value="NA">Namibia</option>
                            <option value="NR">Nauru</option>
                            <option value="NP">Nepal</option>
                            <option value="NL">Netherlands</option>
                            <option value="NZ">New Zealand</option>
                            <option value="NI">Nicaragua</option>
                            <option value="NE">Niger</option>
                            <option value="NG">Nigeria</option>
                            <option value="MK">North Macedonia</option>
                            <option value="NO">Norway</option>
                            <option value="OM">Oman</option>
                            <option value="PK">Pakistan</option>
                            <option value="PW">Palau</option>
                            <option value="PA">Panama</option>
                            <option value="PG">Papua New Guinea</option>
                            <option value="PY">Paraguay</option>
                            <option value="PE">Peru</option>
                            <option value="PH">Philippines</option>
                            <option value="PL">Poland</option>
                            <option value="PT">Portugal</option>
                            <option value="QA">Qatar</option>
                            <option value="RO">Romania</option>
                            <option value="RU">Russia</option>
                            <option value="RW">Rwanda</option>
                            <option value="KN">Saint Kitts and Nevis</option>
                            <option value="LC">Saint Lucia</option>
                            <option value="VC">Saint Vincent and the Grenadines</option>
                            <option value="WS">Samoa</option>
                            <option value="SM">San Marino</option>
                            <option value="ST">Sao Tome and Principe</option>
                            <option value="SA">Saudi Arabia</option>
                            <option value="SN">Senegal</option>
                            <option value="RS">Serbia</option>
                            <option value="SC">Seychelles</option>
                            <option value="SL">Sierra Leone</option>
                            <option value="SG">Singapore</option>
                            <option value="SK">Slovakia</option>
                            <option value="SI">Slovenia</option>
                            <option value="SB">Solomon Islands</option>
                            <option value="SO">Somalia</option>
                            <option value="ZA">South Africa</option>
                            <option value="SS">South Sudan</option>
                            <option value="ES">Spain</option>
                            <option value="LK">Sri Lanka</option>
                            <option value="SD">Sudan</option>
                            <option value="SR">Suriname</option>
                            <option value="SE">Sweden</option>
                            <option value="CH">Switzerland</option>
                            <option value="SY">Syria</option>
                            <option value="TW">Taiwan</option>
                            <option value="TJ">Tajikistan</option>
                            <option value="TZ">Tanzania</option>
                            <option value="TH">Thailand</option>
                            <option value="TL">Timor-Leste</option>
                            <option value="TG">Togo</option>
                            <option value="TO">Tonga</option>
                            <option value="TT">Trinidad and Tobago</option>
                            <option value="TN">Tunisia</option>
                            <option value="TR">Turkey</option>
                            <option value="TM">Turkmenistan</option>
                            <option value="TV">Tuvalu</option>
                            <option value="UG">Uganda</option>
                            <option value="UA">Ukraine</option>
                            <option value="AE">United Arab Emirates</option>
                            <option value="GB">United Kingdom</option>
                            <option value="US">United States</option>
                            <option value="UY">Uruguay</option>
                            <option value="UZ">Uzbekistan</option>
                            <option value="VU">Vanuatu</option>
                            <option value="VA">Vatican City</option>
                            <option value="VE">Venezuela</option>
                            <option value="VN">Vietnam</option>
                            <option value="YE">Yemen</option>
                            <option value="ZM">Zambia</option>
                            <option value="ZW">Zimbabwe</option>
                          </select>
                        </div>
                        <div>
                          <label className="block text-gray-400 text-sm mb-2">Incorporation Date *</label>
                          <input
                            type="date"
                            value={formData.incorporationDate}
                            onChange={(e) => setFormData({ ...formData, incorporationDate: e.target.value })}
                            className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          />
                        </div>
                      </div>

                      <div>
                        <label className="block text-gray-400 text-sm mb-2">Nature of Business *</label>
                        <textarea
                          value={formData.businessNature}
                          onChange={(e) => setFormData({ ...formData, businessNature: e.target.value })}
                          className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          rows={3}
                          placeholder="Describe your business activities..."
                        />
                      </div>

                      <div>
                        <label className="block text-gray-400 text-sm mb-2">Tax ID / Registration Number *</label>
                        <input
                          type="text"
                          value={formData.taxId}
                          onChange={(e) => setFormData({ ...formData, taxId: e.target.value })}
                          className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                          placeholder="Enter your tax ID or business registration number"
                        />
                      </div>

                      <div className="flex gap-4 mt-8">
                        <button
                          onClick={submitBusinessInfo}
                          disabled={submitting}
                          className="flex-1 px-8 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {submitting ? 'Saving...' : 'Save & Continue'}
                        </button>
                      </div>
                    </div>
                  )}

                  {currentStep === 2 && (
                    <div className="space-y-4">
                      <h2 className="text-2xl font-bold text-white mb-4">Corporate Documents</h2>
                      <p className="text-gray-400 mb-4">Upload required corporate documents for verification</p>

                      <div>
                        <label className="block text-gray-400 text-sm mb-2">
                          Certificate of Incorporation * {uploadedDocuments.business_doc && <span className="text-emerald-400">✓ Uploaded</span>}
                        </label>
                        <div className={`border-2 border-dashed rounded-xl p-8 text-center transition-colors cursor-pointer ${
                          uploadedDocuments.business_doc
                            ? 'border-green-500 bg-green-500/10 hover:border-green-400'
                            : 'border-gray-700 hover:border-[#f0b90b]'
                        }`}>
                          <input
                            type="file"
                            accept=".pdf,.jpg,.jpeg,.png"
                            onChange={(e) => handleFileUpload('businessDoc', e)}
                            className="hidden"
                            id="businessDoc"
                          />
                          <label htmlFor="businessDoc" className="cursor-pointer">
                            {uploadedDocuments.business_doc ? (
                              <CheckCircle2 className="w-12 h-12 text-green-400 mx-auto mb-3" />
                            ) : (
                              <Upload className="w-12 h-12 text-gray-400 mx-auto mb-3" />
                            )}
                            <p className={`text-sm mb-1 ${uploadedDocuments.business_doc ? 'text-green-400 font-medium' : 'text-gray-400'}`}>
                              {uploadedDocuments.business_doc ? '✓ Uploaded Successfully' : (uploadedFiles.businessDoc ? uploadedFiles.businessDoc.name : 'Click to upload')}
                            </p>
                            <p className="text-gray-500 text-xs">PDF, JPG, PNG up to 10MB</p>
                          </label>
                        </div>
                      </div>

                      <div className="bg-blue-900/20 border border-blue-800/30 rounded-xl p-4 mt-4">
                        <div className="flex items-start gap-3">
                          <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                          <div className="text-sm text-gray-300">
                            <p className="font-semibold text-white mb-1">Required Documents:</p>
                            <ul className="space-y-1 list-disc list-inside">
                              <li>Certificate of Incorporation</li>
                              <li>Business Registration Document</li>
                              <li>Proof of Company Address</li>
                              <li>Articles of Association (if applicable)</li>
                              <li>Director's ID and Proof of Address</li>
                            </ul>
                            <p className="mt-2 text-xs text-gray-400">
                              Note: Specific requirements may vary based on your country and business type
                            </p>
                          </div>
                        </div>
                      </div>

                      <div className="flex gap-4 mt-8">
                        <button
                          onClick={() => setCurrentStep(1)}
                          disabled={submitting}
                          className="px-8 py-3 bg-[#0b0e11] border border-gray-700 hover:border-gray-600 text-white font-semibold rounded-xl transition-all disabled:opacity-50"
                        >
                          Back
                        </button>
                        <button
                          onClick={submitBusinessDocuments}
                          disabled={submitting}
                          className="flex-1 px-8 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {submitting ? 'Submitting...' : 'Submit for Review'}
                        </button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>

          <div className="space-y-6">
            <div className="bg-gradient-to-br from-[#181a20] to-[#0b0e11] border border-gray-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <Shield className="w-5 h-5 text-emerald-400" />
                Verification Status
              </h3>
              <div className="space-y-3">
                <div className={`p-4 rounded-xl border ${
                  kycLevel === 'none'
                    ? 'bg-gray-800/30 border-gray-700'
                    : kycLevel === 'basic'
                    ? 'bg-blue-900/20 border-blue-800/30'
                    : kycLevel === 'intermediate'
                    ? 'bg-cyan-900/20 border-cyan-800/30'
                    : kycLevel === 'advanced'
                    ? 'bg-emerald-900/20 border-emerald-800/30'
                    : 'bg-purple-900/20 border-purple-800/30'
                }`}>
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-semibold text-white">Current Level</span>
                    <span className={`px-3 py-1 rounded-full text-xs font-bold ${
                      kycLevel === 'none'
                        ? 'bg-gray-700 text-gray-300'
                        : kycLevel === 'basic'
                        ? 'bg-blue-600 text-white'
                        : kycLevel === 'intermediate'
                        ? 'bg-cyan-600 text-white'
                        : kycLevel === 'advanced'
                        ? 'bg-emerald-600 text-white'
                        : 'bg-purple-600 text-white'
                    }`}>
                      {kycLevel === 'none' ? 'Unverified' :
                       kycLevel === 'basic' ? 'Basic' :
                       kycLevel === 'intermediate' ? 'Intermediate' :
                       kycLevel === 'advanced' ? 'Advanced' : 'Entity'}
                    </span>
                  </div>
                  <p className="text-gray-400 text-sm">
                    {existingKYC?.kyc_status === 'pending'
                      ? 'Verification in progress...'
                      : existingKYC?.kyc_status === 'verified'
                      ? 'Verification completed'
                      : 'Complete verification to unlock features'}
                  </p>
                </div>

                <div className="text-sm space-y-2">
                  <div className="flex items-center gap-2">
                    <div className={`w-4 h-4 rounded-full ${kycLevel !== 'none' ? 'bg-emerald-500' : 'bg-gray-700'} flex items-center justify-center`}>
                      {kycLevel !== 'none' && <CheckCircle2 className="w-3 h-3 text-white" />}
                    </div>
                    <span className="text-gray-300">Email Verified</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className={`w-4 h-4 rounded-full ${kycLevel !== 'none' ? 'bg-emerald-500' : 'bg-gray-700'} flex items-center justify-center`}>
                      {kycLevel !== 'none' && <CheckCircle2 className="w-3 h-3 text-white" />}
                    </div>
                    <span className="text-gray-300">Phone Verified</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className={`w-4 h-4 rounded-full ${kycLevel === 'intermediate' || kycLevel === 'advanced' || kycLevel === 'entity' ? 'bg-emerald-500' : 'bg-gray-700'} flex items-center justify-center`}>
                      {(kycLevel === 'intermediate' || kycLevel === 'advanced' || kycLevel === 'entity') && <CheckCircle2 className="w-3 h-3 text-white" />}
                    </div>
                    <span className="text-gray-300">ID Verified</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className={`w-4 h-4 rounded-full ${kycLevel === 'advanced' || kycLevel === 'entity' ? 'bg-emerald-500' : 'bg-gray-700'} flex items-center justify-center`}>
                      {(kycLevel === 'advanced' || kycLevel === 'entity') && <CheckCircle2 className="w-3 h-3 text-white" />}
                    </div>
                    <span className="text-gray-300">Face Verified</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <FileText className="w-5 h-5 text-[#f0b90b]" />
                Basic Verification
              </h3>
              <ul className="space-y-2">
                {benefits.basic.map((benefit, idx) => (
                  <li key={idx} className="flex items-start gap-2 text-sm text-gray-300">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0 mt-0.5" />
                    {benefit}
                  </li>
                ))}
              </ul>
            </div>

            <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <CreditCard className="w-5 h-5 text-cyan-400" />
                Intermediate Verification
              </h3>
              <ul className="space-y-2">
                {benefits.intermediate.map((benefit, idx) => (
                  <li key={idx} className="flex items-start gap-2 text-sm text-gray-300">
                    <CheckCircle2 className="w-4 h-4 text-cyan-400 flex-shrink-0 mt-0.5" />
                    {benefit}
                  </li>
                ))}
              </ul>
            </div>

            <div className="bg-gradient-to-br from-[#f0b90b]/10 to-[#f8d12f]/5 border border-[#f0b90b]/30 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <Shield className="w-5 h-5 text-[#f0b90b]" />
                Advanced Verification
              </h3>
              <ul className="space-y-2">
                {benefits.advanced.map((benefit, idx) => (
                  <li key={idx} className="flex items-start gap-2 text-sm text-gray-300">
                    <CheckCircle2 className="w-4 h-4 text-[#f0b90b] flex-shrink-0 mt-0.5" />
                    {benefit}
                  </li>
                ))}
              </ul>
            </div>

            <div className="bg-gradient-to-br from-purple-600/10 to-purple-800/5 border border-purple-600/30 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <Building2 className="w-5 h-5 text-purple-400" />
                Entity Verification
              </h3>
              <ul className="space-y-2">
                {benefits.entity.map((benefit, idx) => (
                  <li key={idx} className="flex items-start gap-2 text-sm text-gray-300">
                    <CheckCircle2 className="w-4 h-4 text-purple-400 flex-shrink-0 mt-0.5" />
                    {benefit}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default KYC;
