// Booking Service - Firebase operations for bookings
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
import BookingModel from '../models/BookingModel';
import { Timestamp } from 'firebase/firestore';
import { getMaxSlotsForDate, isDateClosed } from './calendarService';

const COLLECTION_NAME = 'bookings';

/**
 * Get all bookings
 * @param {Object} filters - Optional filters { status, trekType, month, year, userId }
 * @returns {Promise<Array<BookingModel>>} Array of booking models
 */
export const getAllBookings = async (filters = {}) => {
  try {
    console.log('getAllBookings called with filters:', filters);
    const firestoreFilters = [];
    
    // Filter by status if provided
    if (filters.status && filters.status !== 'all') {
      firestoreFilters.push({
        field: 'status',
        operator: '==',
        value: filters.status
      });
    }
    
    // Filter by trek type if provided
    if (filters.trekType && filters.trekType !== 'all') {
      firestoreFilters.push({
        field: 'trekType',
        operator: '==',
        value: filters.trekType
      });
    }
    
    // Filter by user ID if provided
    if (filters.userId) {
      firestoreFilters.push({
        field: 'userId',
        operator: '==',
        value: filters.userId
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
        field: 'createdAt',
        operator: '>=',
        value: dateToTimestamp(startDate)
      });
      
      firestoreFilters.push({
        field: 'createdAt',
        operator: '<=',
        value: dateToTimestamp(endDate)
      });
    }
    
    // Filter by trek date range if provided
    if (filters.trekDateFrom || filters.trekDateTo) {
      if (filters.trekDateFrom) {
        firestoreFilters.push({
          field: 'trekDate',
          operator: '>=',
          value: dateToTimestamp(filters.trekDateFrom)
        });
      }
      if (filters.trekDateTo) {
        firestoreFilters.push({
          field: 'trekDate',
          operator: '<=',
          value: dateToTimestamp(filters.trekDateTo)
        });
      }
    }
    
    // If no filters, use getAllDocuments to get all bookings without requiring an index
    // Then sort client-side to avoid Firestore index requirements
    let bookings;
    console.log('Firestore filters count:', firestoreFilters.length, firestoreFilters);
    if (firestoreFilters.length === 0) {
      console.log('Using getAllDocuments (no filters)');
      bookings = await getAllDocuments(COLLECTION_NAME);
      console.log('Fetched all documents:', bookings.length);
      
      // Log date range of fetched bookings for debugging
      if (bookings.length > 0) {
        const dates = bookings
          .map(b => {
            const createdAt = b.createdAt?.toMillis?.() || (b.createdAt?.seconds * 1000);
            return createdAt ? new Date(createdAt) : null;
          })
          .filter(d => d !== null)
          .sort((a, b) => a - b);
        
        if (dates.length > 0) {
          console.log('Date range of bookings:', {
            oldest: dates[0].toISOString().split('T')[0],
            newest: dates[dates.length - 1].toISOString().split('T')[0],
            total: dates.length
          });
        }
      }
      
      // Sort by createdAt descending client-side
      bookings.sort((a, b) => {
        const dateA = a.createdAt?.toMillis?.() || (a.createdAt?.seconds * 1000) || 0;
        const dateB = b.createdAt?.toMillis?.() || (b.createdAt?.seconds * 1000) || 0;
        return dateB - dateA; // Descending order
      });
    } else {
      console.log('Using queryDocuments (with filters)');
      // Use queryDocuments when filters are present
      bookings = await queryDocuments(
        COLLECTION_NAME,
        firestoreFilters,
        'createdAt',
        'desc'
      );
      console.log('Fetched filtered documents:', bookings.length);
    }
    
    // Convert to BookingModel instances
    return bookings
      .map(booking => {
        try {
          // Handle both document snapshot and plain object
          if (booking.id && booking.data) {
            return BookingModel.fromDoc(booking);
          }
          return BookingModel.fromMap(booking);
        } catch (err) {
          console.error('Error converting booking to model:', booking, err);
          return null;
        }
      })
      .filter(booking => booking !== null); // Filter out any null bookings
  } catch (error) {
    console.error('Error getting bookings:', error);
    throw error;
  }
};

/**
 * Get a single booking by ID
 * @param {string} bookingId - Booking ID
 * @returns {Promise<BookingModel>} Booking model
 */
export const getBookingById = async (bookingId) => {
  try {
    const booking = await getDocumentById(COLLECTION_NAME, bookingId);
    if (!booking) {
      return null;
    }
    console.log('Raw booking data from Firestore:', booking);
    console.log('Location field in raw data:', booking.location);
    console.log('Location type:', typeof booking.location);
    const bookingModel = BookingModel.fromMap({ id: booking.id, ...booking });
    console.log('BookingModel location after fromMap:', bookingModel.location);
    return bookingModel;
  } catch (error) {
    console.error(`Error getting booking ${bookingId}:`, error);
    throw error;
  }
};

/**
 * Create a new booking
 * @param {Object|BookingModel} bookingData - Booking data or BookingModel instance
 * @returns {Promise<string>} New booking ID
 */
export const createBooking = async (bookingData) => {
  try {
    let bookingModel;
    
    // If it's already a BookingModel, use it; otherwise create one
    if (bookingData instanceof BookingModel) {
      bookingModel = bookingData;
    } else {
      bookingModel = new BookingModel(bookingData);
    }
    
    // Convert to map and remove id (Firestore will generate it)
    const dataToSave = bookingModel.toMap();
    delete dataToSave.id;
    
    return await addDocument(COLLECTION_NAME, dataToSave);
  } catch (error) {
    console.error('Error creating booking:', error);
    throw error;
  }
};

/**
 * Update a booking
 * @param {string} bookingId - Booking ID
 * @param {Object|BookingModel} updateData - Data to update or BookingModel instance
 * @returns {Promise<void>}
 */
export const updateBooking = async (bookingId, updateData) => {
  try {
    let dataToUpdate;
    
    // If it's a BookingModel, convert to map; otherwise use as-is
    if (updateData instanceof BookingModel) {
      dataToUpdate = updateData.toMap();
      delete dataToUpdate.id; // Don't update the ID
    } else {
      dataToUpdate = { ...updateData };
      
      // Convert dates to timestamps if present
      if (dataToUpdate.trekDate && !(dataToUpdate.trekDate instanceof Timestamp)) {
        dataToUpdate.trekDate = dateToTimestamp(dataToUpdate.trekDate);
      }
    }
    
    // Always update updatedAt
    dataToUpdate.updatedAt = Timestamp.now();
    
    await updateDocument(COLLECTION_NAME, bookingId, dataToUpdate);
  } catch (error) {
    console.error(`Error updating booking ${bookingId}:`, error);
    throw error;
  }
};

/**
 * Count approved bookings for a specific trek date
 * @param {Date|Timestamp|string} trekDate - The trek date to check
 * @param {string} excludeBookingId - Optional booking ID to exclude from count (for updates)
 * @returns {Promise<number>} Number of approved bookings for that date
 */
export const countApprovedBookingsForDate = async (trekDate, excludeBookingId = null) => {
  try {
    // Normalize the trek date to start of day
    let dateObj;
    if (trekDate instanceof Timestamp) {
      dateObj = trekDate.toDate();
    } else if (trekDate instanceof Date) {
      dateObj = trekDate;
    } else if (typeof trekDate === 'string') {
      dateObj = new Date(trekDate);
    } else {
      dateObj = timestampToDate(trekDate);
    }
    
    if (!dateObj || isNaN(dateObj.getTime())) {
      throw new Error('Invalid trek date provided');
    }
    
    // Set to start of day (00:00:00)
    const startOfDay = new Date(dateObj);
    startOfDay.setHours(0, 0, 0, 0);
    
    // Set to end of day (23:59:59.999)
    const endOfDay = new Date(dateObj);
    endOfDay.setHours(23, 59, 59, 999);
    
    // Query for approved bookings on this date
    const firestoreFilters = [
      {
        field: 'status',
        operator: '==',
        value: 'approved'
      },
      {
        field: 'trekDate',
        operator: '>=',
        value: dateToTimestamp(startOfDay)
      },
      {
        field: 'trekDate',
        operator: '<=',
        value: dateToTimestamp(endOfDay)
      }
    ];
    
    const bookings = await queryDocuments(
      COLLECTION_NAME,
      firestoreFilters
    );
    
    // Filter out the excluded booking if provided
    let count = bookings.length;
    if (excludeBookingId) {
      count = bookings.filter(booking => booking.id !== excludeBookingId).length;
    }
    
    return count;
  } catch (error) {
    console.error('Error counting approved bookings for date:', error);
    
    // Check if it's a missing index error
    if (error.code === 'failed-precondition' && error.message && error.message.includes('index')) {
      // Extract the index creation URL from the error message - get the full URL
      // The URL might be in the message or in a separate property
      let indexUrl = error.indexUrl || null;
      
      if (!indexUrl && error.message) {
        // Try to extract from message - look for the full URL pattern
        const urlPattern = /https:\/\/console\.firebase\.google\.com[^\s\)]+/;
        const urlMatch = error.message.match(urlPattern);
        indexUrl = urlMatch ? urlMatch[0] : null;
      }
      
      // Create a custom error with the URL attached
      const indexError = new Error(
        indexUrl 
          ? `Firestore index required. Index creation URL: ${indexUrl}`
          : 'Firestore index required. Please create a composite index on "status" (Ascending) and "trekDate" (Ascending) fields in the Firestore console.'
      );
      indexError.code = 'INDEX_REQUIRED';
      indexError.indexUrl = indexUrl;
      indexError.originalError = error;
      
      throw indexError;
    }
    
    throw error;
  }
};

/**
 * Check if a trek date has reached maximum capacity
 * Uses calendar_config for date-specific maxSlots, or falls back to system_settings default
 * @param {Date|Timestamp|string} trekDate - The trek date to check
 * @param {string} excludeBookingId - Optional booking ID to exclude from count (for updates)
 * @returns {Promise<{isFull: boolean, currentCount: number, maxCapacity: number, isClosed: boolean}>}
 */
export const checkTrekDateCapacity = async (trekDate, excludeBookingId = null) => {
  try {
    // Normalize the trek date
    let dateObj;
    if (trekDate instanceof Timestamp) {
      dateObj = trekDate.toDate();
    } else if (trekDate instanceof Date) {
      dateObj = trekDate;
    } else if (typeof trekDate === 'string') {
      dateObj = new Date(trekDate);
    } else {
      dateObj = timestampToDate(trekDate);
    }
    
    // Check if date is closed
    const closed = await isDateClosed(dateObj);
    if (closed) {
      return {
        isFull: true,
        currentCount: 0,
        maxCapacity: 0,
        isClosed: true
      };
    }
    
    // Get max slots for this date (from calendar_config or system_settings)
    const maxCapacity = await getMaxSlotsForDate(dateObj);
    
    // Count approved bookings
    const currentCount = await countApprovedBookingsForDate(trekDate, excludeBookingId);
    
    return {
      isFull: currentCount >= maxCapacity,
      currentCount,
      maxCapacity,
      isClosed: false
    };
  } catch (error) {
    console.error('Error checking trek date capacity:', error);
    // Fall back to default capacity if error
    const MAX_CAPACITY = 30;
    const currentCount = await countApprovedBookingsForDate(trekDate, excludeBookingId);
    return {
      isFull: currentCount >= MAX_CAPACITY,
      currentCount,
      maxCapacity: MAX_CAPACITY,
      isClosed: false
    };
  }
};

/**
 * Update booking status
 * @param {string} bookingId - Booking ID
 * @param {string} status - New status (pending, approved, rejected, cancelled, changes_required)
 * @param {string} adminNotes - Optional admin notes
 * @returns {Promise<void>}
 * @throws {Error} If trying to approve a booking when the date is full
 */
export const updateBookingStatus = async (bookingId, status, adminNotes = null) => {
  try {
    // Validate inputs
    if (!bookingId) {
      throw new Error('Booking ID is required');
    }
    
    if (!status) {
      throw new Error('Status is required');
    }
    
    const validStatuses = ['pending', 'approved', 'rejected', 'cancelled', 'changes_required'];
    if (!validStatuses.includes(status.toLowerCase())) {
      throw new Error(`Invalid status: ${status}. Must be one of: ${validStatuses.join(', ')}`);
    }
    
    console.log(`Updating booking ${bookingId} status to ${status}`);
    
    // If approving, check capacity first
    if (status === 'approved') {
      console.log('Checking capacity before approval...');
      // Get the booking to check its trek date
      const booking = await getBookingById(bookingId);
      console.log('Booking fetched:', booking);
      
      if (!booking) {
        throw new Error('Booking not found');
      }
      
      if (!booking.trekDate) {
        console.error('Booking missing trekDate:', booking);
        throw new Error('Booking does not have a trek date');
      }
      
      console.log('Booking trekDate:', booking.trekDate, 'Type:', typeof booking.trekDate);
      
      // Check capacity (exclude current booking if it's already approved)
      try {
        const capacity = await checkTrekDateCapacity(booking.trekDate, bookingId);
        console.log('Capacity check result:', capacity);
        
      if (capacity.isClosed) {
        throw new Error(
          `Cannot approve booking: The trek date ${formatBookingDate(booking.trekDate, 'full')} is closed.`
        );
      }
      
      if (capacity.isFull) {
        throw new Error(
          `Cannot approve booking: The trek date ${formatBookingDate(booking.trekDate, 'full')} has reached maximum capacity (${capacity.maxCapacity} trekkers).`
        );
      }
      } catch (capError) {
        console.error('Error during capacity check:', capError);
        // If it's already a capacity error, re-throw it
        if (capError.message && capError.message.includes('maximum capacity')) {
          throw capError;
        }
        // If it's an index error, attach the URL and re-throw
        if (capError.code === 'INDEX_REQUIRED' || (capError.message && capError.message.includes('index'))) {
          // Preserve the index URL if available
          if (capError.indexUrl) {
            const indexError = new Error(capError.message);
            indexError.code = 'INDEX_REQUIRED';
            indexError.indexUrl = capError.indexUrl;
            throw indexError;
          }
          throw capError;
        }
        // Otherwise, wrap it in a more descriptive error
        throw new Error(`Failed to check capacity: ${capError.message || 'Unknown error'}`);
      }
    }
    
    const updateData = {
      status: status,
      updatedAt: Timestamp.now()
    };
    
    if (adminNotes !== null) {
      updateData.adminNotes = adminNotes;
    }
    
    console.log('Updating document with data:', updateData);
    await updateDocument(COLLECTION_NAME, bookingId, updateData);
    console.log('Booking status updated successfully');
  } catch (error) {
    console.error(`Error updating booking status ${bookingId}:`, error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    });
    
    // Provide more specific error messages
    if (error.message) {
      throw error; // Re-throw with original message
    } else if (error.code) {
      throw new Error(`Firebase error (${error.code}): ${error.message || 'Unknown error'}`);
    } else {
      throw new Error(`Failed to update booking status: ${error.message || 'Unknown error'}`);
    }
  }
};

/**
 * Delete a booking
 * @param {string} bookingId - Booking ID
 * @returns {Promise<void>}
 */
export const deleteBooking = async (bookingId) => {
  try {
    await deleteDocument(COLLECTION_NAME, bookingId);
  } catch (error) {
    console.error(`Error deleting booking ${bookingId}:`, error);
    throw error;
  }
};

/**
 * Search bookings by various fields
 * @param {string} searchTerm - Search term
 * @param {Object} filters - Additional filters
 * @returns {Promise<Array<BookingModel>>} Filtered bookings
 */
export const searchBookings = async (searchTerm, filters = {}) => {
  try {
    const allBookings = await getAllBookings(filters);
    
    if (!searchTerm) {
      return allBookings;
    }
    
    const lowerSearchTerm = searchTerm.toLowerCase();
    return allBookings.filter(booking => 
      booking.id?.toLowerCase().includes(lowerSearchTerm) ||
      booking.userId?.toLowerCase().includes(lowerSearchTerm) ||
      booking.affiliation?.toLowerCase().includes(lowerSearchTerm) ||
      booking.notes?.toLowerCase().includes(lowerSearchTerm) ||
      booking.adminNotes?.toLowerCase().includes(lowerSearchTerm)
    );
  } catch (error) {
    console.error('Error searching bookings:', error);
    throw error;
  }
};

/**
 * Subscribe to real-time updates for bookings
 * @param {Function} callback - Callback function to call when data changes
 * @param {Object} filters - Optional filters
 * @returns {Function} Unsubscribe function
 */
export const subscribeToBookings = (callback, filters = {}) => {
  try {
    const firestoreFilters = [];
    
    if (filters.status && filters.status !== 'all') {
      firestoreFilters.push({
        field: 'status',
        operator: '==',
        value: filters.status
      });
    }
    
    if (filters.trekType && filters.trekType !== 'all') {
      firestoreFilters.push({
        field: 'trekType',
        operator: '==',
        value: filters.trekType
      });
    }
    
    if (filters.userId) {
      firestoreFilters.push({
        field: 'userId',
        operator: '==',
        value: filters.userId
      });
    }
    
    return subscribeToCollection(COLLECTION_NAME, (bookings) => {
      // Convert to BookingModel instances
      const bookingModels = bookings.map(booking => BookingModel.fromMap(booking));
      callback(bookingModels);
    }, firestoreFilters);
  } catch (error) {
    console.error('Error setting up bookings listener:', error);
    throw error;
  }
};

/**
 * Format date for display
 * @param {Date|Timestamp|string} date - Date to format
 * @param {string} format - Format type ('short', 'long', 'full')
 * @returns {string} Formatted date string
 */
export const formatBookingDate = (date, format = 'short') => {
  if (!date) return 'Not specified';
  
  let dateObj;
  
  // Handle Firestore Timestamp
  if (date && typeof date.toDate === 'function') {
    dateObj = date.toDate();
  }
  // Handle string dates
  else if (typeof date === 'string') {
    if (date.includes('/')) {
      const dateParts = date.split('/');
      if (dateParts.length === 3) {
        dateObj = new Date(dateParts[2], dateParts[0] - 1, dateParts[1]);
      } else {
        dateObj = new Date(date);
      }
    } else {
      dateObj = new Date(date);
    }
  } 
  // Handle Date objects
  else if (date instanceof Date) {
    dateObj = date;
  } 
  // Try to convert timestamp-like objects
  else if (date && date.seconds) {
    dateObj = new Date(date.seconds * 1000);
  }
  else {
    dateObj = timestampToDate(date);
  }
  
  if (!dateObj || isNaN(dateObj.getTime())) {
    return date?.toString() || 'Not specified';
  }
  
  switch (format) {
    case 'short':
      return dateObj.toLocaleDateString('en-US', { month: 'numeric', day: 'numeric', year: 'numeric' });
    case 'long':
      return dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    case 'full':
      return dateObj.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    default:
      return dateObj.toLocaleDateString();
  }
};

