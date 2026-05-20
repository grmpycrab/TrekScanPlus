import React, { useState, useRef, useEffect } from 'react';
import '../style/ClimbRequest.css';
import GroupBookingsPanel from './GroupBookingsPanel';
import { 
  getAllBookings, 
  getBookingById, 
  updateBookingStatus,
  subscribeToBookings,
  formatBookingDate,
  checkTrekDateCapacity
} from '../../services/bookingService';
import { getUserById } from '../../services/userService';
import { getCurrentUser, onAuthStateChange } from '../../services/firebaseAuthService';
import Attachment from '../../models/Attachment';
import { Timestamp } from 'firebase/firestore';
import { useToast, ToastContainer } from '../../components/Toast';
import { exportToExcel, exportToPDF, exportToCSV } from '../../utils/exportUtils';

function ClimbRequest({ bookingIdToOpen, onBookingOpened }) {
  const [activeTab, setActiveTab] = useState('individual');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showExportMenu, setShowExportMenu] = useState(false);
  const [showFiltersMenu, setShowFiltersMenu] = useState(false);
  const [showMonthMenu, setShowMonthMenu] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedMonth, setSelectedMonth] = useState('all-time'); // Changed to 'all-time' to show all bookings by default
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [loadingDetails, setLoadingDetails] = useState(false);
  
  const filtersRef = useRef(null);
  const exportRef = useRef(null);
  const monthRef = useRef(null);
  const [uploadedFiles, setUploadedFiles] = useState([]);
  const [formData, setFormData] = useState({
    fullName: '',
    phoneNumber: '',
    age: '',
    email: '',
    affiliation: '',
    numberOfPorters: '',
    purposeOfClimb: '',
    location: ''
  });
  const [adminNote, setAdminNote] = useState('');
  const [remarks, setRemarks] = useState([]);
  const [newRemarkText, setNewRemarkText] = useState('');
  const [currentAdminName, setCurrentAdminName] = useState('Admin');
  const [showDeleteRemarkModal, setShowDeleteRemarkModal] = useState(false);
  const [remarkToDelete, setRemarkToDelete] = useState(null);
  const [capacityInfo, setCapacityInfo] = useState(null);
  const [checkingCapacity, setCheckingCapacity] = useState(false);
  const [selectedFile, setSelectedFile] = useState(null);
  const [showFileViewer, setShowFileViewer] = useState(false);

  // Toast notifications
  const { toasts, removeToast, success, error: showError, warning, info } = useToast();

  // Climb requests from Firebase
  const [requests, setRequests] = useState([]);

  // Fetch bookings from Firebase and map to UI format
  const fetchClimbRequests = async () => {
    try {
      setLoading(true);
      setError(null);
      
      console.log('Fetching bookings with filters:', { selectedStatus, selectedMonth });
      
      const filters = {};
      
      // Only add status filter if not 'all'
      if (selectedStatus !== 'all') {
        filters.status = selectedStatus.toLowerCase();
      }
      
      // Add month filter if needed
      if (selectedMonth !== 'all-time') {
        const now = new Date();
        if (selectedMonth === 'this-month') {
          filters.month = now.getMonth() + 1;
          filters.year = now.getFullYear();
        } else if (selectedMonth === 'last-month') {
          const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1);
          filters.month = lastMonth.getMonth() + 1;
          filters.year = lastMonth.getFullYear();
        } else if (selectedMonth === 'this-year') {
          filters.year = now.getFullYear();
        }
      }
      
      console.log('Calling getAllBookings with filters:', filters);
      let fetchedBookings = await getAllBookings(filters);
      console.log('Fetched bookings:', fetchedBookings?.length || 0, fetchedBookings);
      
      if (!fetchedBookings || fetchedBookings.length === 0) {
        console.log('No bookings found');
        setRequests([]);
        setLoading(false);
        return;
      }
      
      // Fetch user data for each booking and map to UI format
      console.log('Processing bookings and fetching user data...');
      const requestsWithUserData = await Promise.all(
        fetchedBookings.map(async (booking) => {
          try {
            // Fetch user data
            const user = booking.userId ? await getUserById(booking.userId) : null;
            
            // Map BookingModel to UI format
            return {
              id: booking.id,
              requestId: booking.id,
              userId: booking.userId,
              name: user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User',
              email: user?.email || 'N/A',
              phone: booking.phoneNumber || 'N/A',
              phoneNumber: booking.phoneNumber || 'N/A',
              age: user?.birthDate ? calculateAge(user.birthDate) : 'N/A',
              affiliation: booking.affiliation || 'N/A',
              numberOfPorters: booking.numberOfPorters || 0,
              purposeOfClimb: booking.notes || booking.trekType || 'N/A',
              location: (booking.location !== null && booking.location !== undefined) ? booking.location : null,
              requestedDate: formatBookingDate(booking.trekDate, 'full'),
              dateSubmitted: formatBookingDate(booking.createdAt, 'full'),
              status: capitalizeStatus(booking.status),
              documents: booking.attachments || [],
              attachments: booking.attachments || [],
              adminNotes: booking.adminNotes || '',
              lastAdminNote: booking.adminNotes || '',
              trekType: booking.trekType,
              // Keep original booking for reference
              _booking: booking
            };
          } catch (userErr) {
            console.error('Error processing booking:', booking.id, userErr);
            // Return booking even if user fetch fails
            return {
              id: booking.id,
              requestId: booking.id,
              userId: booking.userId,
              name: 'Unknown User',
              email: 'N/A',
              phone: booking.phoneNumber || 'N/A',
              phoneNumber: booking.phoneNumber || 'N/A',
              age: 'N/A',
              isSeniorCitizen: false,
              affiliation: booking.affiliation || 'N/A',
              numberOfPorters: booking.numberOfPorters || 0,
              purposeOfClimb: booking.notes || booking.trekType || 'N/A',
              location: (booking.location !== null && booking.location !== undefined) ? booking.location : null,
              requestedDate: formatBookingDate(booking.trekDate, 'full'),
              dateSubmitted: formatBookingDate(booking.createdAt, 'full'),
              status: capitalizeStatus(booking.status),
              documents: booking.attachments || [],
              attachments: booking.attachments || [],
              adminNotes: booking.adminNotes || '',
              lastAdminNote: booking.adminNotes || '',
              trekType: booking.trekType,
              _booking: booking
            };
          }
        })
      );
      
      // Sort by date submitted (createdAt) - latest first
      const sortedRequests = requestsWithUserData.sort((a, b) => {
        const dateA = a._booking?.createdAt;
        const dateB = b._booking?.createdAt;
        
        // Handle Firestore Timestamp objects
        const timestampA = dateA?.toDate ? dateA.toDate().getTime() : 
                         dateA ? new Date(dateA).getTime() : 0;
        const timestampB = dateB?.toDate ? dateB.toDate().getTime() : 
                         dateB ? new Date(dateB).getTime() : 0;
        
        // Sort in descending order (latest first)
        return timestampB - timestampA;
      });
      
      console.log('Mapped requests:', sortedRequests.length);
      setRequests(sortedRequests);
    } catch (err) {
      console.error('Error fetching bookings:', err);
      console.error('Error details:', err.message, err.stack);
      setError(`Failed to load climb requests: ${err.message || 'Unknown error'}`);
      setRequests([]);
    } finally {
      setLoading(false);
    }
  };

  // Helper function to calculate age from birthDate
  const calculateAge = (birthDate) => {
    if (!birthDate) return 'N/A';
    try {
      const birth = new Date(birthDate);
      const today = new Date();
      let age = today.getFullYear() - birth.getFullYear();
      const monthDiff = today.getMonth() - birth.getMonth();
      if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
        age--;
      }
      return age.toString();
    } catch {
      return 'N/A';
    }
  };

  // Helper function to determine if user is a senior citizen (60+ years old)
  const isSeniorCitizen = (birthDate) => {
    if (!birthDate) return false;
    try {
      const age = parseInt(calculateAge(birthDate));
      return !isNaN(age) && age >= 60;
    } catch {
      return false;
    }
  };

  // Helper function to capitalize status for display
  const capitalizeStatus = (status) => {
    if (!status) return 'Pending';
    // Handle underscore-separated statuses like "changes_required"
    if (status.includes('_')) {
      return status.split('_').map(word => 
        word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
      ).join(' ');
    }
    return status.charAt(0).toUpperCase() + status.slice(1).toLowerCase();
  };

  // Helper function to format location for display
  const formatLocation = (location) => {
    if (!location) return 'Not specified';
    const locationMap = {
      'inside_san_isidro': 'Inside San Isidro',
      'inside_davao_oriental': 'Inside Davao Oriental',
      'outside_davao_oriental': 'Outside Davao Oriental'
    };
    return locationMap[location] || location.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
  };

  // Check authentication and load requests on component mount and when filters change
  useEffect(() => {
    // Check if user is authenticated
    const currentUser = getCurrentUser();
    if (!currentUser) {
      setError('Please log in to view climb requests.');
      setLoading(false);
      return;
    }

    // Store current admin display name/email for remarks
    setCurrentAdminName(
      currentUser.displayName || currentUser.email || 'Admin'
    );

    // Set up auth state listener
    const unsubscribe = onAuthStateChange((user) => {
      if (!user) {
        setError('Session expired. Please log in again.');
        setLoading(false);
        setRequests([]);
      } else {
        // User is authenticated, fetch requests
        fetchClimbRequests();
      }
    });

    // Set up real-time subscription for bookings
    let unsubscribeBookings = null;
    if (currentUser) {
      unsubscribeBookings = subscribeToBookings(() => {
        // Refresh requests when bookings change (including cancellations)
        fetchClimbRequests();
      });
    }

    // Fetch requests if authenticated
    if (currentUser) {
      fetchClimbRequests();
    }

    return () => {
      unsubscribe();
      if (unsubscribeBookings) {
        unsubscribeBookings();
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedStatus, selectedMonth]);

  const handleActionClick = async (requestId, action) => {
    if (action === 'view') {
      try {
        setLoadingDetails(true);
        console.log('Fetching booking details for:', requestId);
        
        if (!requestId) {
          throw new Error('Request ID is missing');
        }
        
        const booking = await getBookingById(requestId);
        console.log('Booking fetched:', booking);
        
        if (!booking) {
          throw new Error('Booking not found');
        }
        
        // Fetch user data
        const user = booking.userId ? await getUserById(booking.userId) : null;
        console.log('User data:', user);
        console.log('Booking data:', booking);
        console.log('Booking location (hometown):', booking.location);
        
        // Check capacity for this trek date
        setCheckingCapacity(true);
        try {
          const capacity = await checkTrekDateCapacity(booking.trekDate, booking.id);
          setCapacityInfo(capacity);
          console.log('Capacity info:', capacity);
        } catch (capErr) {
          console.error('Error checking capacity:', capErr);
          setCapacityInfo(null);
        } finally {
          setCheckingCapacity(false);
        }
        
        // Map booking to UI format
        const request = {
          id: booking.id,
          requestId: booking.id,
          userId: booking.userId,
          name: user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User',
          email: user?.email || 'N/A',
          phone: booking.phoneNumber || 'N/A',
          phoneNumber: booking.phoneNumber || 'N/A',
          age: user?.birthDate ? calculateAge(user.birthDate) : 'N/A',
          isSeniorCitizen: user?.birthDate ? isSeniorCitizen(user.birthDate) : false,
          affiliation: booking.affiliation || 'N/A',
          numberOfPorters: booking.numberOfPorters || 0,
          purposeOfClimb: booking.notes || booking.trekType || 'N/A',
          location: (booking.location !== null && booking.location !== undefined) ? booking.location : null,
          requestedDate: formatBookingDate(booking.trekDate, 'short'),
          dateSubmitted: formatBookingDate(booking.createdAt, 'short'),
          status: capitalizeStatus(booking.status),
          documents: booking.attachments || [],
          attachments: booking.attachments || [],
          adminNotes: booking.adminNotes || '',
          lastAdminNote: booking.adminNotes || '',
          trekType: booking.trekType,
          _booking: booking
        };
        
        setSelectedRequest({
          ...request,
          requestedDate: formatBookingDate(booking.trekDate, 'full'),
          dateSubmitted: formatBookingDate(booking.createdAt, 'full')
        });
        
        // Populate form with request data
        // Ensure location (hometown) is fetched from booking
        // Get location directly from booking object, handling null/undefined/empty string
        // Check multiple sources: booking.location, booking._booking?.location, request.location
        const hometown = (booking && booking.location !== null && booking.location !== undefined) 
          ? booking.location 
          : (booking && booking._booking && booking._booking.location !== null && booking._booking.location !== undefined)
          ? booking._booking.location
          : (request && request.location !== null && request.location !== undefined)
          ? request.location
          : (request && request._booking && request._booking.location !== null && request._booking.location !== undefined)
          ? request._booking.location
          : '';
        console.log('Hometown value being set:', hometown);
        console.log('Booking object:', booking);
        console.log('Booking location:', booking?.location);
        console.log('Booking location type:', typeof booking?.location);
        console.log('Booking._booking location:', booking?._booking?.location);
        console.log('Request location:', request?.location);
        console.log('Request._booking location:', request?._booking?.location);
        
        setFormData({
          fullName: request.name || '',
          phoneNumber: request.phoneNumber || '',
          age: request.age || '',
          email: request.email || '',
          isSeniorCitizen: request.isSeniorCitizen || false,
          affiliation: request.affiliation || '',
          numberOfPorters: request.numberOfPorters ? String(request.numberOfPorters) : '',
          purposeOfClimb: request.purposeOfClimb || '',
          location: hometown
        });
        
        // Map attachments to documents format for display
        const documents = (booking.attachments || []).map(att => {
          try {
            // Handle both Attachment instances and plain objects
            let attachment;
            if (att instanceof Attachment) {
              attachment = att;
            } else if (att && typeof att === 'object') {
              attachment = Attachment.fromMap(att);
            } else {
              // If att is just a string URL or something else
              attachment = Attachment.fromMap({ downloadURL: att || '' });
            }
            
            return {
              name: attachment?.fileName || attachment?.name || 'Unknown',
              fileName: attachment?.fileName || attachment?.name || 'Unknown',
              url: attachment?.downloadURL || attachment?.url || '',
              downloadURL: attachment?.downloadURL || attachment?.url || '',
              type: attachment?.mimeType || attachment?.type || 'application/octet-stream',
              mimeType: attachment?.mimeType || attachment?.type || 'application/octet-stream',
              size: attachment?.size || 0
            };
          } catch (attErr) {
            console.error('Error processing attachment:', att, attErr);
            // Return a safe default
            return {
              name: 'Unknown',
              fileName: 'Unknown',
              url: att?.downloadURL || att?.url || '',
              downloadURL: att?.downloadURL || att?.url || '',
              type: 'application/octet-stream',
              mimeType: 'application/octet-stream',
              size: 0
            };
          }
        });
        setUploadedFiles(documents);

        // Parse admin remarks (backward compatible with legacy plain text)
        try {
          if (booking.adminNotes) {
            const parsed = JSON.parse(booking.adminNotes);
            if (Array.isArray(parsed)) {
              setRemarks(parsed);
            } else if (typeof parsed === 'string') {
              // Legacy: single string stored as JSON string
              setRemarks([{
                id: `${Date.now()}-${Math.random()}`,
                text: parsed,
                adminName: currentAdminName,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
                edited: false
              }]);
            } else {
              // Fallback: treat as plain text
              setRemarks([{
                id: `${Date.now()}-${Math.random()}`,
                text: String(booking.adminNotes),
                adminName: currentAdminName,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
                edited: false
              }]);
            }
          } else {
            setRemarks([]);
          }
        } catch {
          // adminNotes is plain text or invalid JSON
          if (booking.adminNotes) {
            setRemarks([{
              id: `${Date.now()}-${Math.random()}`,
              text: String(booking.adminNotes),
              adminName: currentAdminName,
              createdAt: new Date().toISOString(),
              updatedAt: new Date().toISOString(),
              edited: false
            }]);
          } else {
            setRemarks([]);
          }
        }

        // Keep legacy single-note state for compatibility (no longer used for UI)
        setAdminNote(booking.adminNotes || '');
        console.log('Setting selected request and showing modal');
        setShowDetailsModal(true);
        setLoadingDetails(false);
        
        // Reset capacity info when closing modal
        if (!showDetailsModal) {
          setCapacityInfo(null);
        }
      } catch (err) {
        console.error('Error fetching request details:', err);
        console.error('Error stack:', err.stack);
        setLoadingDetails(false);
        showError(`Failed to load request details: ${err.message || 'Unknown error'}`, 6000);
      }
    } else if (action === 'approve' || action === 'reject' || action === 'pending') {
      try {
        // Map UI status to BookingModel status (lowercase)
        const statusMap = {
          'approve': 'approved',
          'reject': 'rejected',
          'pending': 'pending'
        };
        const bookingStatus = statusMap[action] || 'pending';
        
        await updateBookingStatus(requestId, bookingStatus);
        
        // Show success message
        const actionMessages = {
          'approved': 'Request approved successfully',
          'rejected': 'Request rejected successfully',
          'pending': 'Request status updated to pending'
        };
        success(actionMessages[bookingStatus] || 'Request status updated successfully', 4000);
        
        // Update local state with capitalized status for display
        const displayStatus = capitalizeStatus(bookingStatus);
        setRequests(prevRequests => 
          prevRequests.map(request => 
            request.id === requestId 
              ? { ...request, status: displayStatus }
              : request
          )
        );
        
        // Update selected request if modal is open
        if (selectedRequest && selectedRequest.id === requestId) {
          setSelectedRequest({ ...selectedRequest, status: displayStatus });
          // Refresh capacity info after approval
          if (bookingStatus === 'approved' && selectedRequest._booking?.trekDate) {
            try {
              const capacity = await checkTrekDateCapacity(selectedRequest._booking.trekDate, requestId);
              setCapacityInfo(capacity);
            } catch (capErr) {
              console.error('Error refreshing capacity:', capErr);
            }
          }
        }
      } catch (err) {
        console.error('Error updating request status:', err);
        console.error('Error details:', {
          message: err.message,
          code: err.code,
          stack: err.stack
        });
        
        // Check if error is about capacity
        if (err.message && err.message.includes('maximum capacity')) {
          showError(err.message, 7000);
          // Refresh capacity info if modal is open
          if (selectedRequest && selectedRequest.id === requestId && selectedRequest._booking?.trekDate) {
            try {
              const capacity = await checkTrekDateCapacity(selectedRequest._booking.trekDate, requestId);
              setCapacityInfo(capacity);
            } catch (capErr) {
              console.error('Error refreshing capacity:', capErr);
            }
          }
        } else if (err.message && err.message.includes('trek date')) {
          // Error about missing trek date
          showError(err.message, 6000);
        } else if (err.message && err.message.includes('Booking not found')) {
          showError('Booking not found. Please refresh the page and try again.', 6000);
        } else if (err.code === 'INDEX_REQUIRED' || err.message?.includes('index') || err.indexUrl) {
          // Firestore index error - show with longer duration and instructions
          let indexMessage = '⚠️ Firestore index required for capacity checking. ';
          
          // Extract index URL from error object or message
          let indexUrl = err.indexUrl;
          if (!indexUrl && err.message) {
            // Try to extract full URL from message
            const urlPattern = /https:\/\/console\.firebase\.google\.com[^\s\)]+/;
            const urlMatch = err.message.match(urlPattern);
            indexUrl = urlMatch ? urlMatch[0] : null;
          }
          
          if (indexUrl) {
            // Show the full URL and make it copyable
            indexMessage = '⚠️ Firestore index required for capacity checking. Click the button below to create it.';
            
            // Log the full URL in a way that's easy to copy
            console.error('═══════════════════════════════════════════════════════');
            console.error('🔗 FIREBASE INDEX CREATION URL (COPY THIS):');
            console.error('═══════════════════════════════════════════════════════');
            console.error(indexUrl);
            console.error('═══════════════════════════════════════════════════════');
            console.error('📝 STEP-BY-STEP INSTRUCTIONS:');
            console.error('1. Click the "Create Index" button in the error message above');
            console.error('2. Or copy the URL above and open it in a new browser tab');
            console.error('3. You should see the Firebase Console with the index pre-configured');
            console.error('4. Click "Create Index" button');
            console.error('5. Wait 1-5 minutes for the index to build (you\'ll see status: "Building" → "Enabled")');
            console.error('6. Once enabled, refresh this page and try approving again');
            console.error('═══════════════════════════════════════════════════════');
            
            // Store URL in a global variable for easy access
            try {
              window.firebaseIndexUrl = indexUrl;
              console.error('💡 TIP: The URL is also stored in window.firebaseIndexUrl');
              console.error('   You can copy it by running: copy(window.firebaseIndexUrl)');
            } catch (e) {
              // Ignore if can't store
            }
            
            // Show error with action button
            showError(indexMessage, 20000, {
              label: '🔗 Create Index',
              onClick: () => {
                window.open(indexUrl, '_blank');
                console.log('Opening index creation URL:', indexUrl);
              }
            });
          } else {
            indexMessage += '\n\nPlease create a composite index in Firestore Console:\n- Collection: bookings\n- Fields: status (Ascending), trekDate (Ascending)';
            console.error('📝 Manual Index Creation:');
            console.error('1. Go to Firebase Console → Firestore → Indexes');
            console.error('2. Click "Create Index"');
            console.error('3. Collection: bookings');
            console.error('4. Add field: status (Ascending)');
            console.error('5. Add field: trekDate (Ascending)');
            console.error('6. Click "Create"');
          }
          
          showError(indexMessage, 15000);
          // Also log the full error for debugging
          console.error('Firestore index error. Full error:', err);
        } else if (err.message && err.message.includes('Failed to check capacity')) {
          showError(err.message, 6000);
        } else {
          // Show the actual error message if available, otherwise generic message
          const errorMessage = err.message || 'Failed to update request status. Please try again.';
          showError(errorMessage, 6000);
        }
        throw err; // Re-throw to let caller handle it
      }
    }
  };

  const handleFileOpen = (file, e) => {
    // Prevent any default behavior (form submission, etc.)
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }
    // Handle both old format (file.url) and new format (file.downloadURL or file.url)
    const url = file.downloadURL || file.url;
    if (url) {
      setSelectedFile(file);
      setShowFileViewer(true);
    }
  };

  const getFileIcon = (fileType) => {
    if (fileType.startsWith('image/')) {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2" stroke="currentColor" strokeWidth="2"/>
          <circle cx="8.5" cy="8.5" r="1.5" stroke="currentColor" strokeWidth="2"/>
          <polyline points="21,15 16,10 5,21" stroke="currentColor" strokeWidth="2"/>
        </svg>
      );
    } else if (fileType.includes('pdf')) {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
          <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
        </svg>
      );
    } else if (fileType.includes('word') || fileType.includes('document')) {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
          <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
          <line x1="16" y1="13" x2="8" y2="13" stroke="currentColor" strokeWidth="2"/>
        </svg>
      );
    }
    return (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
        <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
      </svg>
    );
  };

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (filtersRef.current && !filtersRef.current.contains(event.target)) {
        setShowFiltersMenu(false);
      }
      if (exportRef.current && !exportRef.current.contains(event.target)) {
        setShowExportMenu(false);
      }
      if (monthRef.current && !monthRef.current.contains(event.target)) {
        setShowMonthMenu(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleExport = async (format) => {
    try {
      setShowExportMenu(false);
      
      // Get the data to export (use filtered requests which already respect datePicker and status filters)
      // filteredRequests includes search term filter, but we want to export all data matching the datePicker/status filters
      // So we use requests (which is already filtered by datePicker and status) unless search is active
      const dataToExport = searchTerm ? filteredRequests : requests;
      
      if (!dataToExport || dataToExport.length === 0) {
        showError('No data available to export.', 4000);
        return;
      }

      // Show loading message
      info(`Exporting ${dataToExport.length} record(s) as ${format.toUpperCase()}...`, 3000);

      // Generate descriptive filename based on filters
      let filename = 'climb-requests';
      
      // Add date filter to filename
      if (selectedMonth === 'this-month') {
        filename += '-this-month';
      } else if (selectedMonth === 'last-month') {
        filename += '-last-month';
      } else if (selectedMonth === 'this-year') {
        filename += '-this-year';
      } else {
        filename += '-all-time';
      }
      
      // Add status filter to filename
      if (selectedStatus !== 'all') {
        filename += `-${selectedStatus}`;
      }
      
      // Add search indicator if search is active
      if (searchTerm) {
        filename += '-filtered';
      }

      // Export based on format
      if (format === 'excel') {
        await exportToExcel(dataToExport, filename);
        success(`Successfully exported ${dataToExport.length} record(s) as Excel.`, 4000);
      } else if (format === 'pdf') {
        await exportToPDF(dataToExport, filename);
        success(`Successfully exported ${dataToExport.length} record(s) as PDF.`, 4000);
      } else if (format === 'csv') {
        exportToCSV(dataToExport, filename);
        success(`Successfully exported ${dataToExport.length} record(s) as CSV.`, 4000);
      } else {
        showError(`Unsupported export format: ${format}`, 4000);
      }
    } catch (error) {
      console.error('Export error:', error);
      showError(
        error.message || `Failed to export data as ${format.toUpperCase()}. Please try again.`,
        6000
      );
    }
  };

  const handleFilterChange = (status) => {
    setSelectedStatus(status);
    setShowFiltersMenu(false);
  };

  const handleMonthChange = (month) => {
    setSelectedMonth(month);
    setShowMonthMenu(false);
  };

  // Search is now handled by local filtering in filteredRequests
  // No need to refetch when search term changes

  // Handle opening booking from notification
  useEffect(() => {
    if (bookingIdToOpen) {
      // Wait a bit for the component to mount and data to load
      const timer = setTimeout(async () => {
        try {
          await handleActionClick(bookingIdToOpen, 'view');
        } catch (error) {
          console.error('Error opening booking from notification:', error);
          showError('Failed to open booking details. Please try again.');
        } finally {
          // Notify parent that booking has been opened (or attempted)
          if (onBookingOpened) {
            onBookingOpened();
          }
        }
      }, 500);
      
      return () => clearTimeout(timer);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bookingIdToOpen]);

  // Filter requests locally based on search term
  const filteredRequests = requests.filter(request => {
    if (!searchTerm) return true;
    
    const lowerSearchTerm = searchTerm.toLowerCase();
    return (
      request.name?.toLowerCase().includes(lowerSearchTerm) ||
      request.id?.toLowerCase().includes(lowerSearchTerm) ||
      request.userId?.toLowerCase().includes(lowerSearchTerm) ||
      request.email?.toLowerCase().includes(lowerSearchTerm) ||
      request.requestId?.toLowerCase().includes(lowerSearchTerm) ||
      request.affiliation?.toLowerCase().includes(lowerSearchTerm)
    );
  });

  // Determine if the currently selected request is approved/cancelled (used to lock actions)
  const selectedStatusLower =
    selectedRequest && (selectedRequest._booking?.status || selectedRequest.status)
      ? (selectedRequest._booking?.status || selectedRequest.status).toLowerCase()
      : '';
  const isSelectedApproved = selectedStatusLower === 'approved';
  const isSelectedCancelled = selectedStatusLower === 'cancelled';

  return (
    <div className="climb-main">
      {/* ── Tab switcher ──────────────────────────────────────── */}
      <div className="cr-tab-bar">
        {[
          { key: 'individual', label: 'Individual Bookings' },
          { key: 'groups',     label: 'Group Bookings' },
        ].map(({ key, label }) => (
          <button
            key={key}
            className={`cr-tab${activeTab === key ? ' cr-tab-active' : ''}`}
            onClick={() => setActiveTab(key)}
          >
            {label}
          </button>
        ))}
      </div>

      {/* ── Group Bookings Panel ──────────────────────────────── */}
      {activeTab === 'groups' && <GroupBookingsPanel />}

      {/* ── Individual Bookings (existing content) ────────────── */}
      {activeTab === 'individual' && <>

        {/* Error Display */}
        {error && (
          <div style={{
            padding: '12px 16px',
            marginBottom: '16px',
            backgroundColor: '#fee',
            border: '1px solid #fcc',
            borderRadius: '4px',
            color: '#c33'
          }}>
            <strong>Error:</strong> {error}
          </div>
        )}
        
        {/* Request Management Card */}
        <div className="request-management-card">
          <div className="card-header">
          </div>
          
          {/* Table Header with Search and Actions */}
          <div className="table-header-bar">
            <div className="table-search-container">
              <svg className="table-search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M21 21L15 15M17 10C17 13.866 13.866 17 10 17C6.13401 17 3 13.866 3 10C3 6.13401 6.13401 3 10 3C13.866 3 17 6.13401 17 10Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              <input
                type="text"
                className="table-search-input"
                placeholder="Search..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            
            <div className="table-actions">
              {/* Filters Dropdown */}
              <div className="table-action-dropdown" ref={filtersRef}>
                <button className="table-action-btn" onClick={() => setShowFiltersMenu(!showFiltersMenu)}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <line x1="4" y1="6" x2="20" y2="6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                    <circle cx="8" cy="6" r="2" fill="currentColor"/>
                    <line x1="4" y1="18" x2="20" y2="18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                    <circle cx="16" cy="18" r="2" fill="currentColor"/>
                  </svg>
                  Filters
                </button>
                {showFiltersMenu && (
                  <div className="action-dropdown-menu">
                    <div className="dropdown-header">Filter by Status</div>
                    <button 
                      className={`dropdown-item ${selectedStatus === 'all' ? 'active' : ''}`}
                      onClick={() => handleFilterChange('all')}
                    >
                      All Status
                    </button>
                    <button 
                      className={`dropdown-item ${selectedStatus === 'pending' ? 'active' : ''}`}
                      onClick={() => handleFilterChange('pending')}
                    >
                      Pending
                    </button>
                    <button 
                      className={`dropdown-item ${selectedStatus === 'approved' ? 'active' : ''}`}
                      onClick={() => handleFilterChange('approved')}
                    >
                      Approved
                    </button>
                    <button 
                      className={`dropdown-item ${selectedStatus === 'rejected' ? 'active' : ''}`}
                      onClick={() => handleFilterChange('rejected')}
                    >
                      Rejected
                    </button>
                  </div>
                )}
              </div>
              
              {/* Export Dropdown */}
              <div className="table-action-dropdown" ref={exportRef}>
                <button className="table-action-btn" onClick={() => setShowExportMenu(!showExportMenu)}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M21 15V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V15" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    <polyline points="7 10 12 15 17 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                  </svg>
                  Export
                </button>
                {showExportMenu && (
                  <div className="action-dropdown-menu">
                    <button className="dropdown-item" onClick={() => handleExport('excel')}>
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                        <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                        <line x1="16" y1="13" x2="8" y2="13" stroke="currentColor" strokeWidth="2"/>
                        <line x1="16" y1="17" x2="8" y2="17" stroke="currentColor" strokeWidth="2"/>
                      </svg>
                      Export as Excel
                    </button>
                    <button className="dropdown-item" onClick={() => handleExport('pdf')}>
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                        <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                      </svg>
                      Export as PDF
                    </button>
                    <button className="dropdown-item" onClick={() => handleExport('csv')}>
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                        <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                        <line x1="16" y1="13" x2="8" y2="13" stroke="currentColor" strokeWidth="2"/>
                        <line x1="16" y1="17" x2="8" y2="17" stroke="currentColor" strokeWidth="2"/>
                      </svg>
                      Export as CSV
                    </button>
                  </div>
                )}
              </div>
              
              {/* Month Dropdown */}
              <div className="table-action-dropdown" ref={monthRef}>
                <button className="table-action-btn" onClick={() => setShowMonthMenu(!showMonthMenu)}>
                  {selectedMonth === 'this-month' ? 'This Month' : 
                   selectedMonth === 'last-month' ? 'Last Month' :
                   selectedMonth === 'this-year' ? 'This Year' : 
                   selectedMonth === 'all-time' ? 'All Time' : 'All Time'}
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <polyline points="6 9 12 15 18 9" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
                {showMonthMenu && (
                  <div className="action-dropdown-menu">
                    <button 
                      className={`dropdown-item ${selectedMonth === 'this-month' ? 'active' : ''}`}
                      onClick={() => handleMonthChange('this-month')}
                    >
                      This Month
                    </button>
                    <button 
                      className={`dropdown-item ${selectedMonth === 'last-month' ? 'active' : ''}`}
                      onClick={() => handleMonthChange('last-month')}
                    >
                      Last Month
                    </button>
                    <button 
                      className={`dropdown-item ${selectedMonth === 'this-year' ? 'active' : ''}`}
                      onClick={() => handleMonthChange('this-year')}
                    >
                      This Year
                    </button>
                    <button 
                      className={`dropdown-item ${selectedMonth === 'all-time' ? 'active' : ''}`}
                      onClick={() => handleMonthChange('all-time')}
                    >
                      All Time
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
          
          <div className="table-container">
            <table className="requests-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Affiliation</th>
                  <th>Date Submitted</th>
                  <th>Requested Date</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredRequests.length === 0 ? (
                  <tr>
                    <td colSpan="6" className="table-empty-state">
                      <div className="empty-state-content">
                        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" className="empty-state-icon">
                          <path d="M9 12H15M9 16H15M17 21H7C5.89543 21 5 20.1046 5 19V5C5 3.89543 5.89543 3 7 3H12.5858C12.851 3 13.1054 3.10536 13.2929 3.29289L18.7071 8.70711C18.8946 8.89464 19 9.149 19 9.41421V19C19 20.1046 18.1046 21 17 21Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                        </svg>
                        <h3 className="empty-state-title">No requests found</h3>
                        <p className="empty-state-message">
                          {searchTerm || selectedStatus !== 'all' 
                            ? 'Try adjusting your search or filter criteria.' 
                            : 'There are no climb requests at the moment.'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filteredRequests.map((request) => (
                    <tr key={request.id}>
                      <td>{request.name || 'N/A'}</td>
                      <td>{request.affiliation || 'N/A'}</td>
                      <td>{request.dateSubmitted || 'Not specified'}</td>
                      <td>{request.requestedDate || 'Not specified'}</td>
                      <td>
                        <span className={`status-badge ${(request.status || 'Pending').toLowerCase().replace(/\s+/g, '_')}`}>
                          {request.status || 'Pending'}
                        </span>
                      </td>
                      <td>
                        <button 
                          className="view-details-btn"
                          onClick={() => {
                            console.log('View Details clicked for request:', request.id, request);
                            handleActionClick(request.id, 'view');
                          }}
                          disabled={loadingDetails}
                        >
                          {loadingDetails ? (
                            <>
                              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" className="spinning">
                                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" strokeDasharray="31.416" strokeDashoffset="31.416">
                                  <animate attributeName="stroke-dasharray" dur="2s" values="0 31.416;15.708 15.708;0 31.416;0 31.416" repeatCount="indefinite"/>
                                  <animate attributeName="stroke-dashoffset" dur="2s" values="0;-15.708;-31.416;-31.416" repeatCount="indefinite"/>
                                </circle>
                              </svg>
                              Loading...
                            </>
                          ) : (
                            <>
                              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                                <path d="M1 12S5 4 12 4S23 12 23 12S19 20 12 20S1 12 1 12Z" stroke="currentColor" strokeWidth="2"/>
                                <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="2"/>
                              </svg>
                              View Details
                            </>
                          )}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Details Modal */}
        {showDetailsModal && selectedRequest && (
          <div className="modal-backdrop" onClick={() => {
            setShowDetailsModal(false);
            setCapacityInfo(null);
          }}>
            <div className="modal-card" onClick={(e) => e.stopPropagation()}>
              <div className="modal-header">
                <div className="header-content">
                  <div className="header-title-row">
                    <h3>Request Details</h3>
                    <span className="request-id-badge">{selectedRequest.id}</span>
                  </div>
                  <p className="submission-date">Submitted on {selectedRequest.dateSubmitted ? formatBookingDate(selectedRequest._booking?.createdAt || selectedRequest.dateSubmitted, 'full') : 'Not specified'}</p>
                </div>
                <div className="header-right">
                  <span className={`status-badge-modal ${selectedRequest.status.toLowerCase().replace(/\s+/g, '_')}`}>
                    <span className="status-dot"></span>
                    {selectedRequest.status.toUpperCase()}
                  </span>
                  <button 
                    className="close-btn"
                    onClick={() => {
                      setShowDetailsModal(false);
                      setCapacityInfo(null);
                    }}
                  >
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                      <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </button>
                </div>
              </div>
              <div className="modal-body">
                <form className="request-details-form">
                  {/* Request Information Section */}
                  <div className="requester-section">
                    <div className="section-title-green">
                      <div className="section-line-green"></div>
                      <h4>Request Information</h4>
                    </div>
                    
                    {/* Full Name */}
                    <div className="form-field">
                      <label>Full Name</label>
                      <input
                        type="text"
                        name="fullName"
                        value={formData.fullName && formData.fullName.trim() ? formData.fullName : 'Not specified'}
                        readOnly
                        className="form-input form-input-readonly"
                      />
                    </div>

                    {/* Phone Number and Age (Side-by-Side) */}
                    <div className="form-row">
                      <div className="form-field form-field-half">
                        <label>Phone Number</label>
                        <input
                          type="text"
                          name="phoneNumber"
                          value={formData.phoneNumber && formData.phoneNumber.trim() ? formData.phoneNumber : 'Not specified'}
                          readOnly
                          className="form-input form-input-readonly"
                        />
                      </div>
                      <div className="form-field form-field-half">
                        <label>Age</label>
                        <input
                          type="text"
                          name="age"
                          value={formData.age && formData.age.trim() ? formData.age : 'Not specified'}
                          readOnly
                          className="form-input form-input-readonly"
                        />
                      </div>
                    </div>

                    {/* Senior Citizen */}
                    <div className="form-field">
                      <label>Senior Citizen</label>
                      <input
                        type="text"
                        name="isSeniorCitizen"
                        value={formData.isSeniorCitizen ? 'Yes' : 'No'}
                        readOnly
                        className="form-input form-input-readonly"
                      />
                    </div>

                    {/* Email Address */}
                    <div className="form-field">
                      <label>Email Address</label>
                      <input
                        type="email"
                        name="email"
                        value={formData.email && formData.email.trim() ? formData.email : 'Not specified'}
                        readOnly
                        className="form-input form-input-readonly"
                      />
                    </div>

                    {/* Affiliation and Number of Porters (Side-by-Side) */}
                    <div className="form-row">
                      <div className="form-field form-field-half">
                        <label>Affiliation</label>
                        <input
                          type="text"
                          name="affiliation"
                          value={formData.affiliation && formData.affiliation.trim() ? formData.affiliation : 'Not specified'}
                          readOnly
                          className="form-input form-input-readonly"
                        />
                      </div>
                      <div className="form-field form-field-half">
                        <label>Number of Porters</label>
                        <input
                          type="text"
                          name="numberOfPorters"
                          value={formData.numberOfPorters ? (typeof formData.numberOfPorters === 'string' ? formData.numberOfPorters.trim() : String(formData.numberOfPorters)) : 'Not specified'}
                          readOnly
                          className="form-input form-input-readonly"
                        />
                      </div>
                    </div>

                    {/* Purpose of Climb */}
                    <div className="form-field">
                      <label>Purpose of Climb</label>
                      <input
                        type="text"
                        name="purposeOfClimb"
                        value={formData.purposeOfClimb && formData.purposeOfClimb.trim() ? formData.purposeOfClimb : 'Not specified'}
                        readOnly
                        className="form-input form-input-readonly"
                      />
                    </div>

                    {/* Location */}
                    <div className="form-field">
                      <label>Hometown</label>
                      <input
                        type="text"
                        name="location"
                        value={formData.location ? formatLocation(formData.location) : 'Not specified'}
                        readOnly
                        className="form-input form-input-readonly"
                      />
                    </div>
                  </div>

                  {/* Documents Section */}
                  <div className="documents-section">
                    <div className="section-title-green">
                      <div className="section-line-green"></div>
                      <h4>Documents</h4>
                    </div>
                    {uploadedFiles && uploadedFiles.length > 0 ? (
                      <div className="documents-card-grid">
                        {uploadedFiles.map((file, index) => {
                          // Format file size
                          const fileSize = file.size 
                            ? file.size > 1024 * 1024 
                              ? `${(file.size / (1024 * 1024)).toFixed(2)} MB`
                              : `${(file.size / 1024).toFixed(2)} KB`
                            : 'N/A';
                          
                          // Get file type
                          const fileType = file.type || file.mimeType || 'application/pdf';
                          const isPDF = fileType.includes('pdf');
                          
                          // Format date (use createdAt from booking or current date)
                          const fileDate = selectedRequest?._booking?.createdAt 
                            ? (() => {
                                const date = selectedRequest._booking.createdAt instanceof Timestamp 
                                  ? selectedRequest._booking.createdAt.toDate() 
                                  : new Date(selectedRequest._booking.createdAt);
                                return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
                              })()
                            : new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
                          
                          return (
                            <div key={index} className="document-card">
                              <div className="document-card-thumbnail">
                                {isPDF ? (
                                  <div className="document-pdf-preview">
                                    <svg width="40" height="40" viewBox="0 0 24 24" fill="none">
                                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="#ef4444" strokeWidth="2"/>
                                      <polyline points="14,2 14,8 20,8" stroke="#ef4444" strokeWidth="2"/>
                                      <line x1="16" y1="13" x2="8" y2="13" stroke="#ef4444" strokeWidth="2"/>
                                    </svg>
                                  </div>
                                ) : (
                                  <div className="document-image-preview">
                                    <img 
                                      src={file.downloadURL || file.url || ''} 
                                      alt={file.name || file.fileName || 'Document'}
                                      onError={(e) => {
                                        e.target.style.display = 'none';
                                        e.target.nextSibling.style.display = 'flex';
                                      }}
                                    />
                                    <div className="document-fallback-icon" style={{ display: 'none' }}>
                                      {getFileIcon(fileType)}
                                    </div>
                                  </div>
                                )}
                              </div>
                              <div className="document-card-content">
                                <h5 className="document-card-title">{file.name || file.fileName || `Document ${index + 1}`}</h5>
                                <div className="document-card-meta">
                                  <span className="document-card-type">PDF</span>
                                  <span className="document-card-size">{fileSize}</span>
                                </div>
                                <div className="document-card-date">Added {fileDate}</div>
                              </div>
                              <button 
                                type="button"
                                className="document-card-view-btn"
                                onClick={(e) => handleFileOpen(file, e)}
                              >
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                                  <path d="M1 12S5 4 12 4S23 12 23 12S19 20 12 20S1 12 1 12Z" stroke="currentColor" strokeWidth="2"/>
                                  <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="2"/>
                                </svg>
                                View
                              </button>
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="file-drop-zone">
                        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" className="document-icon">
                          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                          <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                          <line x1="16" y1="13" x2="8" y2="13" stroke="currentColor" strokeWidth="2"/>
                          <line x1="16" y1="17" x2="8" y2="17" stroke="currentColor" strokeWidth="2"/>
                          <polyline points="10,9 9,9 8,9" stroke="currentColor" strokeWidth="2"/>
                        </svg>
                        <p className="drop-zone-text">No files uploaded</p>
                      </div>
                    )}
                  </div>

                {/* Remarks Section */}
                <div className="status-update-section">
                  <div className="section-title-green">
                    <div className="section-line-green"></div>
                    <h4>
                      Remarks
                      {remarks && remarks.length > 0 && (
                        <span className="remarks-count">({remarks.length})</span>
                      )}
                    </h4>
                  </div>

                  {/* Remarks List (shown above input) */}
                  {remarks && remarks.length > 0 && (
                    <div className="remarks-list">
                      {remarks.map((remark) => {
                        const createdDate = remark.createdAt
                          ? new Date(remark.createdAt)
                          : new Date();
                        const updatedDate = remark.updatedAt
                          ? new Date(remark.updatedAt)
                          : createdDate;
                        const timestampLabel = updatedDate.toLocaleString();

                        return (
                          <div key={remark.id} className="remark-card">
                            <div className="remark-header">
                              <div className="remark-meta">
                                <span className="remark-admin">
                                  {remark.adminName || 'Admin'}
                                </span>
                                <span className="remark-timestamp">
                                  {timestampLabel}
                                  {remark.edited && ' (edited)'}
                                </span>
                              </div>
                              {!isSelectedApproved && !isSelectedCancelled && (
                                <div className="remark-actions">
                                  <button
                                    type="button"
                                    className="remark-delete-btn"
                                    onClick={() => {
                                      if (isSelectedApproved || isSelectedCancelled) return;
                                      setRemarkToDelete(remark);
                                      setShowDeleteRemarkModal(true);
                                    }}
                                  >
                                    Delete
                                  </button>
                                </div>
                              )}
                            </div>

                            <div className="remark-body">
                              <div className="remark-text">
                                {remark.text}
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}

                  {/* New Remark Input (kept visible below the list) */}
                  <div
                    className={isSelectedApproved || isSelectedCancelled ? 'remarks-input-wrapper disabled' : 'remarks-input-wrapper'}
                    onClick={() => {
                      if (isSelectedApproved) {
                        warning(
                          'Cannot Add Remark: Remarks cannot be edited after the request has been approved.',
                          6000
                        );
                      } else if (isSelectedCancelled) {
                        warning(
                          'Cannot Add Remark: Remarks cannot be edited after the request has been cancelled.',
                          6000
                        );
                      }
                    }}
                    style={{ position: 'relative' }}
                  >
                    <textarea
                      value={newRemarkText}
                      onChange={(e) => setNewRemarkText(e.target.value)}
                      placeholder="Add Remarks"
                      className="status-update-textarea"
                      rows="3"
                      disabled={isSelectedApproved || isSelectedCancelled}
                      onFocus={() => {
                        if (isSelectedApproved) {
                          warning(
                            'Cannot Add Remark: Remarks cannot be edited after the request has been approved.',
                            6000
                          );
                        } else if (isSelectedCancelled) {
                          warning(
                            'Cannot Add Remark: Remarks cannot be edited after the request has been cancelled.',
                            6000
                          );
                        }
                      }}
                    />
                  </div>
                  <button
                    type="button"
                    className="send-update-btn"
                    onClick={async () => {
                      if (isSelectedApproved || isSelectedCancelled) return;
                      const text = newRemarkText.trim();
                      if (!text || !selectedRequest) return;

                      const now = new Date().toISOString();
                      const newRemark = {
                        id: `${Date.now()}-${Math.random()}`,
                        text,
                        adminName: currentAdminName,
                        createdAt: now,
                        updatedAt: now,
                        edited: false
                      };

                      const updatedRemarks = [...remarks, newRemark];
                      setRemarks(updatedRemarks);
                      setNewRemarkText('');

                      try {
                        // Change status to "changes_required" when adding a remark
                        await updateBookingStatus(
                          selectedRequest.id,
                          'changes_required',
                          JSON.stringify(updatedRemarks)
                        );

                        // Update the selected request status immediately in the modal
                        setSelectedRequest(prev => ({
                          ...prev,
                          status: 'Changes Required',
                          _booking: {
                            ...prev._booking,
                            status: 'changes_required'
                          }
                        }));

                        success('Remark added successfully!', 4000);
                        await fetchClimbRequests();

                        if (selectedRequest._booking?.trekDate) {
                          try {
                            const capacity = await checkTrekDateCapacity(
                              selectedRequest._booking.trekDate,
                              selectedRequest.id
                            );
                            setCapacityInfo(capacity);
                          } catch (capErr) {
                            console.error('Error refreshing capacity:', capErr);
                          }
                        }
                      } catch (err) {
                        console.error('Error adding remark:', err);
                        showError('Failed to add remark. Please try again.', 5000);
                      }
                    }}
                    disabled={!newRemarkText.trim() || !selectedRequest || isSelectedApproved || isSelectedCancelled}
                  >
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                      <path d="M22 2L11 13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M22 2L15 22L11 13L2 9L22 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                    Add Remarks
                  </button>
                </div>
                </form>
              </div>
              {/* Capacity Warning */}
              {capacityInfo && (
                <div className="capacity-warning-section" style={{
                  margin: '16px 24px',
                  padding: '12px 16px',
                  borderRadius: '8px',
                  backgroundColor: capacityInfo.isClosed ? '#fee' : 
                                  capacityInfo.isFull ? '#fee' : 
                                  capacityInfo.currentCount >= capacityInfo.maxCapacity - 3 ? '#fff3cd' : '#e7f3ff',
                  border: `1px solid ${capacityInfo.isClosed ? '#fcc' : 
                                  capacityInfo.isFull ? '#fcc' : 
                                  capacityInfo.currentCount >= capacityInfo.maxCapacity - 3 ? '#ffc107' : '#b3d9ff'}`,
                  color: capacityInfo.isClosed ? '#c33' : 
                        capacityInfo.isFull ? '#c33' : 
                        capacityInfo.currentCount >= capacityInfo.maxCapacity - 3 ? '#856404' : '#004085'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                      {capacityInfo.isClosed || capacityInfo.isFull ? (
                        <path d="M12 8V12M12 16H12.01M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      ) : (
                        <path d="M12 9V13M12 17H12.01M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      )}
                    </svg>
                    <div>
                      <strong>
                        {capacityInfo.isClosed 
                          ? `Date is Closed` 
                          : capacityInfo.isFull 
                          ? `Maximum Capacity Reached` 
                          : capacityInfo.currentCount >= capacityInfo.maxCapacity - 3
                          ? `Near Capacity Warning`
                          : `Capacity Information`}
                      </strong>
                      <div style={{ marginTop: '4px', fontSize: '14px' }}>
                        {capacityInfo.isClosed 
                          ? `This trek date is closed. Approval is not allowed.`
                          : capacityInfo.isFull 
                          ? `This trek date has reached the maximum capacity of ${capacityInfo.maxCapacity} trekkers. Approval is not allowed.`
                          : `This trek date currently has ${capacityInfo.currentCount} approved ${capacityInfo.currentCount === 1 ? 'trekker' : 'trekkers'} out of ${capacityInfo.maxCapacity} maximum. ${capacityInfo.maxCapacity - capacityInfo.currentCount} ${capacityInfo.maxCapacity - capacityInfo.currentCount === 1 ? 'spot remains' : 'spots remain'}.`}
                      </div>
                    </div>
                  </div>
                </div>
              )}
              
              {selectedRequest && (
                <div className="modal-actions">
                  <div className="action-buttons">
                    {(() => {
                      // Check if status is pending - check multiple possible locations
                      const bookingStatus = selectedRequest._booking?.status?.toLowerCase();
                      const displayStatus = selectedRequest.status?.toLowerCase();
                      const status = bookingStatus || displayStatus || '';
                      const isPending = status === 'pending';
                      const isDateFull = capacityInfo?.isFull || capacityInfo?.isClosed || false;
                      
                      return (
                        <>
                          <button 
                            className="btn-reject-new"
                            disabled={!isPending}
                            onClick={async () => {
                              if (!isPending) return;
                              try {
                                await handleActionClick(selectedRequest.id, 'reject');
                                setShowDetailsModal(false);
                                await fetchClimbRequests();
                              } catch (err) {
                                console.error('Error rejecting request:', err);
                                showError('Failed to reject request. Please try again.', 5000);
                              }
                            }}
                            style={{ opacity: isPending ? 1 : 0.5, cursor: isPending ? 'pointer' : 'not-allowed' }}
                          >
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                              <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
                              <path d="M12 8v4M12 16h.01" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                            </svg>
                            Reject Request
                          </button>
                          <button 
                            className="btn-approve-new"
                            disabled={!isPending || isDateFull}
                            onClick={async () => {
                              if (!isPending || isDateFull) return;
                              
                              console.log('Approve button clicked for booking:', selectedRequest.id);
                              console.log('Selected request:', selectedRequest);
                              
                              try {
                                await handleActionClick(selectedRequest.id, 'approve');
                                setShowDetailsModal(false);
                                await fetchClimbRequests();
                              } catch (err) {
                                console.error('Error approving request:', err);
                                console.error('Error details:', {
                                  message: err.message,
                                  code: err.code,
                                  stack: err.stack
                                });
                                
                                // Check if error is about capacity
                                if (err.message && err.message.includes('maximum capacity')) {
                                  showError(err.message, 7000);
                                  // Refresh capacity info
                                  if (selectedRequest._booking?.trekDate) {
                                    try {
                                      const capacity = await checkTrekDateCapacity(selectedRequest._booking.trekDate, selectedRequest.id);
                                      setCapacityInfo(capacity);
                                    } catch (capErr) {
                                      console.error('Error refreshing capacity:', capErr);
                                    }
                                  }
                                } else {
                                  // Show the actual error message
                                  const errorMessage = err.message || 'Failed to approve request. Please try again.';
                                  showError(errorMessage, 6000);
                                }
                              }
                            }}
                            style={{ 
                              opacity: (isPending && !isDateFull) ? 1 : 0.5, 
                              cursor: (isPending && !isDateFull) ? 'pointer' : 'not-allowed' 
                            }}
                            title={isDateFull ? 'Cannot approve: This trek date has reached maximum capacity' : ''}
                          >
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                              <path d="M20 6L9 17L4 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                            </svg>
                            Approve Request
                          </button>
                        </>
                      );
                    })()}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
        
        {/* Toast Notifications */}
        <ToastContainer toasts={toasts} removeToast={removeToast} />
        
        {/* File Viewer Overlay */}
        {showFileViewer && selectedFile && (
          <div className="file-viewer-overlay" onClick={() => setShowFileViewer(false)}>
            <div className="file-viewer-container" onClick={(e) => e.stopPropagation()}>
              <div className="file-viewer-header">
                <div className="file-viewer-title">
                  <h3>{selectedFile.name || selectedFile.fileName || 'Document'}</h3>
                  <span className="file-viewer-type">
                    {selectedFile.type?.includes('pdf') ? 'PDF' : 
                     selectedFile.type?.startsWith('image/') ? 'Image' : 
                     'Document'}
                  </span>
                </div>
                <button 
                  className="file-viewer-close"
                  onClick={() => setShowFileViewer(false)}
                  aria-label="Close"
                >
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                    <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
              </div>
              <div className="file-viewer-content">
                {(() => {
                  const url = selectedFile.downloadURL || selectedFile.url;
                  const fileType = selectedFile.type || selectedFile.mimeType || '';
                  const isPDF = fileType.includes('pdf');
                  const isImage = fileType.startsWith('image/');
                  
                  if (isPDF) {
                    return (
                      <iframe
                        src={url}
                        className="file-viewer-iframe"
                        title={selectedFile.name || 'PDF Document'}
                      />
                    );
                  } else if (isImage) {
                    return (
                      <div className="file-viewer-image-container">
                        <img
                          src={url}
                          alt={selectedFile.name || 'Image'}
                          className="file-viewer-image"
                          onError={(e) => {
                            e.target.style.display = 'none';
                            e.target.nextSibling.style.display = 'flex';
                          }}
                        />
                        <div className="file-viewer-fallback" style={{ display: 'none' }}>
                          <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                            <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                          </svg>
                          <p>Unable to display image</p>
                        </div>
                      </div>
                    );
                  } else {
                    // For other file types, show download option
                    return (
                      <div className="file-viewer-unsupported">
                        <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
                          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                          <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                        </svg>
                        <p>Preview not available for this file type</p>
                        <a
                          href={url}
                          download={selectedFile.name || selectedFile.fileName}
                          className="file-viewer-download-btn"
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                            <path d="M21 15V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V15" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                            <polyline points="7 10 12 15 17 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                            <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                          </svg>
                          Download File
                        </a>
                      </div>
                    );
                  }
                })()}
              </div>
            </div>
          </div>
        )}

      {/* Delete Remark Confirmation Modal */}
      {showDeleteRemarkModal && remarkToDelete && (
        <div className="modal-backdrop" onClick={() => {
          setShowDeleteRemarkModal(false);
          setRemarkToDelete(null);
        }}>
          <div className="delete-remark-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
            <div className="delete-remark-header">
              <h3>Delete Remark</h3>
            </div>
            <div className="delete-remark-body">
              <p>Are you sure you want to delete this remark?</p>
              <div className="delete-remark-preview">
                <p className="delete-remark-text">{remarkToDelete.text}</p>
              </div>
            </div>
            <div className="delete-remark-actions">
              <button 
                className="delete-remark-btn-cancel"
                onClick={() => {
                  setShowDeleteRemarkModal(false);
                  setRemarkToDelete(null);
                }}
              >
                Cancel
              </button>
              <button 
                className="delete-remark-btn-confirm"
                onClick={async () => {
                  if (!remarkToDelete || !selectedRequest) return;

                  const updated = remarks.filter(
                    (r) => r.id !== remarkToDelete.id
                  );
                  setRemarks(updated);
                  setShowDeleteRemarkModal(false);
                  setRemarkToDelete(null);

                  try {
                    const bookingStatus =
                      selectedRequest._booking?.status ||
                      selectedRequest.status?.toLowerCase() ||
                      'pending';

                    await updateBookingStatus(
                      selectedRequest.id,
                      bookingStatus,
                      JSON.stringify(updated)
                    );

                    success('Remark deleted successfully!', 4000);
                    await fetchClimbRequests();
                  } catch (err) {
                    console.error('Error deleting remark:', err);
                    showError(
                      'Failed to delete remark. Please try again.',
                      5000
                    );
                  }
                }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      </>}

      {/* Toast Notifications */}
      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

export default ClimbRequest;


