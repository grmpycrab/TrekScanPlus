// Climb Request Service - Firebase operations for climb requests
import { 
  getAllDocuments, 
  getDocumentById, 
  addDocument, 
  updateDocument, 
  deleteDocument, 
  queryDocuments,
  subscribeToCollection,
  timestampToDate,
  dateToTimestamp
} from './firebaseService';

const COLLECTION_NAME = 'climbRequests';

/**
 * Get all climb requests
 * @param {Object} filters - Optional filters { status, month, year }
 * @returns {Promise<Array>} Array of climb requests
 */
export const getAllClimbRequests = async (filters = {}) => {
  try {
    const firestoreFilters = [];
    
    // Filter by status if provided
    if (filters.status && filters.status !== 'all') {
      firestoreFilters.push({
        field: 'status',
        operator: '==',
        value: filters.status
      });
    }
    
    // Filter by date range if month/year provided
    if (filters.month || filters.year) {
      const startDate = new Date();
      const endDate = new Date();
      
      if (filters.year) {
        startDate.setFullYear(filters.year, 0, 1);
        endDate.setFullYear(filters.year, 11, 31);
      }
      
      if (filters.month) {
        const monthIndex = parseInt(filters.month) - 1;
        startDate.setMonth(monthIndex, 1);
        endDate.setMonth(monthIndex + 1, 0);
      }
      
      firestoreFilters.push({
        field: 'dateSubmitted',
        operator: '>=',
        value: dateToTimestamp(startDate)
      });
      
      firestoreFilters.push({
        field: 'dateSubmitted',
        operator: '<=',
        value: dateToTimestamp(endDate)
      });
    }
    
    const requests = await queryDocuments(
      COLLECTION_NAME,
      firestoreFilters,
      'dateSubmitted',
      'desc'
    );
    
    // Convert Firestore timestamps to readable dates
    return requests.map(request => ({
      ...request,
      dateSubmitted: request.dateSubmitted ? timestampToDate(request.dateSubmitted) : null,
      requestedDate: request.requestedDate ? timestampToDate(request.requestedDate) : null,
      createdAt: request.createdAt ? timestampToDate(request.createdAt) : null,
      updatedAt: request.updatedAt ? timestampToDate(request.updatedAt) : null
    }));
  } catch (error) {
    console.error('Error getting climb requests:', error);
    throw error;
  }
};

/**
 * Get a single climb request by ID
 * @param {string} requestId - Request ID
 * @returns {Promise<Object>} Climb request data
 */
export const getClimbRequestById = async (requestId) => {
  try {
    const request = await getDocumentById(COLLECTION_NAME, requestId);
    if (!request) {
      return null;
    }
    
    // Convert timestamps
    return {
      ...request,
      dateSubmitted: request.dateSubmitted ? timestampToDate(request.dateSubmitted) : null,
      requestedDate: request.requestedDate ? timestampToDate(request.requestedDate) : null,
      createdAt: request.createdAt ? timestampToDate(request.createdAt) : null,
      updatedAt: request.updatedAt ? timestampToDate(request.updatedAt) : null
    };
  } catch (error) {
    console.error(`Error getting climb request ${requestId}:`, error);
    throw error;
  }
};

/**
 * Create a new climb request
 * @param {Object} requestData - Climb request data
 * @returns {Promise<string>} New request ID
 */
export const createClimbRequest = async (requestData) => {
  try {
    // Convert dates to timestamps
    const dataToSave = {
      ...requestData,
      requestedDate: requestData.requestedDate ? dateToTimestamp(requestData.requestedDate) : null,
      dateSubmitted: dateToTimestamp(new Date()),
      status: requestData.status || 'Pending'
    };
    
    return await addDocument(COLLECTION_NAME, dataToSave);
  } catch (error) {
    console.error('Error creating climb request:', error);
    throw error;
  }
};

/**
 * Update a climb request
 * @param {string} requestId - Request ID
 * @param {Object} updateData - Data to update
 * @returns {Promise<void>}
 */
export const updateClimbRequest = async (requestId, updateData) => {
  try {
    // Convert dates to timestamps if present
    const dataToUpdate = { ...updateData };
    
    if (dataToUpdate.requestedDate) {
      dataToUpdate.requestedDate = dateToTimestamp(dataToUpdate.requestedDate);
    }
    
    if (dataToUpdate.dateSubmitted) {
      dataToUpdate.dateSubmitted = dateToTimestamp(dataToUpdate.dateSubmitted);
    }
    
    await updateDocument(COLLECTION_NAME, requestId, dataToUpdate);
  } catch (error) {
    console.error(`Error updating climb request ${requestId}:`, error);
    throw error;
  }
};

/**
 * Update climb request status
 * @param {string} requestId - Request ID
 * @param {string} status - New status (Pending, Approved, Rejected)
 * @param {string} adminNote - Optional admin note
 * @returns {Promise<void>}
 */
export const updateClimbRequestStatus = async (requestId, status, adminNote = '') => {
  try {
    const updateData = {
      status: status,
      updatedAt: new Date()
    };
    
    if (adminNote) {
      updateData.adminNote = adminNote;
      updateData.lastAdminNote = adminNote;
      updateData.lastAdminNoteDate = new Date();
    }
    
    await updateClimbRequest(requestId, updateData);
  } catch (error) {
    console.error(`Error updating climb request status ${requestId}:`, error);
    throw error;
  }
};

/**
 * Delete a climb request
 * @param {string} requestId - Request ID
 * @returns {Promise<void>}
 */
export const deleteClimbRequest = async (requestId) => {
  try {
    await deleteDocument(COLLECTION_NAME, requestId);
  } catch (error) {
    console.error(`Error deleting climb request ${requestId}:`, error);
    throw error;
  }
};

/**
 * Search climb requests by name or ID
 * @param {string} searchTerm - Search term
 * @param {Object} filters - Additional filters
 * @returns {Promise<Array>} Filtered climb requests
 */
export const searchClimbRequests = async (searchTerm, filters = {}) => {
  try {
    const allRequests = await getAllClimbRequests(filters);
    
    if (!searchTerm) {
      return allRequests;
    }
    
    const lowerSearchTerm = searchTerm.toLowerCase();
    return allRequests.filter(request => 
      request.name?.toLowerCase().includes(lowerSearchTerm) ||
      request.id?.toLowerCase().includes(lowerSearchTerm) ||
      request.email?.toLowerCase().includes(lowerSearchTerm) ||
      request.requestId?.toLowerCase().includes(lowerSearchTerm)
    );
  } catch (error) {
    console.error('Error searching climb requests:', error);
    throw error;
  }
};

/**
 * Subscribe to real-time updates for climb requests
 * @param {Function} callback - Callback function to call when data changes
 * @param {Object} filters - Optional filters
 * @returns {Function} Unsubscribe function
 */
export const subscribeToClimbRequests = (callback, filters = {}) => {
  try {
    const firestoreFilters = [];
    
    if (filters.status && filters.status !== 'all') {
      firestoreFilters.push({
        field: 'status',
        operator: '==',
        value: filters.status
      });
    }
    
    return subscribeToCollection(COLLECTION_NAME, (requests) => {
      // Convert timestamps
      const convertedRequests = requests.map(request => ({
        ...request,
        dateSubmitted: request.dateSubmitted ? timestampToDate(request.dateSubmitted) : null,
        requestedDate: request.requestedDate ? timestampToDate(request.requestedDate) : null,
        createdAt: request.createdAt ? timestampToDate(request.createdAt) : null,
        updatedAt: request.updatedAt ? timestampToDate(request.updatedAt) : null
      }));
      
      callback(convertedRequests);
    }, firestoreFilters);
  } catch (error) {
    console.error('Error setting up climb requests listener:', error);
    throw error;
  }
};

/**
 * Format date for display
 * @param {Date|Timestamp|string} date - Date to format
 * @param {string} format - Format type ('short', 'long', 'full')
 * @returns {string} Formatted date string
 */
export const formatRequestDate = (date, format = 'short') => {
  if (!date) return 'Not specified';
  
  let dateObj;
  
  // Handle string dates (already formatted)
  if (typeof date === 'string') {
    // Check if it's already a formatted date string (contains '/')
    if (date.includes('/')) {
      // Try to parse it
      const dateParts = date.split('/');
      if (dateParts.length === 3) {
        dateObj = new Date(dateParts[2], dateParts[0] - 1, dateParts[1]);
      } else {
        // Try ISO string
        dateObj = new Date(date);
      }
    } else {
      // Try parsing as ISO string
      dateObj = new Date(date);
    }
  } else if (date instanceof Date) {
    dateObj = date;
  } else {
    // Assume it's a Firestore Timestamp
    dateObj = timestampToDate(date);
  }
  
  if (!dateObj || isNaN(dateObj.getTime())) {
    return date; // Return original if can't parse
  }
  
  switch (format) {
    case 'short':
      return dateObj.toLocaleDateString('en-US', { month: 'numeric', day: 'numeric', year: 'numeric' });
    case 'long':
      return dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    case 'full':
      return dateObj.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
    default:
      return dateObj.toLocaleDateString();
  }
};

