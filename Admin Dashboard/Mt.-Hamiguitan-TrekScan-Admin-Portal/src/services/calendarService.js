// Calendar Service - Firebase operations for calendar configuration
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
import { Timestamp, doc, setDoc } from 'firebase/firestore';
import { db } from '../config/firebase';

const CALENDAR_CONFIG_COLLECTION = 'calendar_config';
const SYSTEM_SETTINGS_COLLECTION = 'system_settings';
const CALENDAR_DOC_ID = 'calendar';

/**
 * Get calendar default settings from system_settings/calendar
 * @returns {Promise<Object>} Calendar settings
 */
export const getCalendarSettings = async () => {
  try {
    const settings = await getDocumentById(SYSTEM_SETTINGS_COLLECTION, CALENDAR_DOC_ID);
    // Return defaults if document doesn't exist
    if (!settings) {
      return {
        advanceBookingDays: 1825,
        allowWeekendBookings: true,
        criticalThreshold: 5,
        defaultMaxSlots: 30,
        lastUpdated: null
      };
    }
    return {
      advanceBookingDays: settings.advanceBookingDays || 1825,
      allowWeekendBookings: settings.allowWeekendBookings !== undefined ? settings.allowWeekendBookings : true,
      criticalThreshold: settings.criticalThreshold || 5,
      defaultMaxSlots: settings.defaultMaxSlots || 30,
      lastUpdated: settings.lastUpdated ? timestampToDate(settings.lastUpdated) : null
    };
  } catch (error) {
    console.error('Error getting calendar settings:', error);
    // Return defaults if document doesn't exist
    return {
      advanceBookingDays: 1825,
      allowWeekendBookings: true,
      criticalThreshold: 5,
      defaultMaxSlots: 30,
      lastUpdated: null
    };
  }
};

/**
 * Update calendar default settings
 * @param {Object} settings - Settings to update
 * @returns {Promise<void>}
 */
export const updateCalendarSettings = async (settings) => {
  try {
    await updateDocument(SYSTEM_SETTINGS_COLLECTION, CALENDAR_DOC_ID, {
      ...settings,
      lastUpdated: Timestamp.now()
    });
  } catch (error) {
    console.error('Error updating calendar settings:', error);
    throw error;
  }
};

/**
 * Get calendar configuration for a specific date
 * @param {Date|string} date - Date to get configuration for (format: YYYY-MM-DD)
 * @returns {Promise<Object|null>} Calendar config for the date or null if not found
 */
export const getCalendarConfigForDate = async (date) => {
  try {
    // Format date as YYYY-MM-DD
    let dateStr;
    if (date instanceof Date) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      dateStr = `${year}-${month}-${day}`;
    } else {
      dateStr = date;
    }
    
    const config = await getDocumentById(CALENDAR_CONFIG_COLLECTION, dateStr);
    
    if (!config) {
      return null;
    }
    
    return {
      id: dateStr,
      date: config.date ? timestampToDate(config.date) : new Date(dateStr),
      maxSlots: config.maxSlots || null,
      isClosed: config.isClosed || false,
      customNote: config.customNote || null,
      reason: config.reason || null,
      lastUpdated: config.lastUpdated ? timestampToDate(config.lastUpdated) : null
    };
  } catch (error) {
    // Document doesn't exist, return null
    if (error.message && error.message.includes('not found')) {
      return null;
    }
    console.error('Error getting calendar config for date:', error);
    throw error;
  }
};

/**
 * Get all calendar configurations within a date range
 * @param {Date} startDate - Start date
 * @param {Date} endDate - End date
 * @returns {Promise<Array>} Array of calendar configs
 */
export const getCalendarConfigsInRange = async (startDate, endDate) => {
  try {
    const startStr = formatDateForId(startDate);
    const endStr = formatDateForId(endDate);
    
    // Query documents where ID is between start and end dates
    // Note: Firestore doesn't support range queries on document IDs directly
    // So we'll get all configs and filter, or use date field if it exists
    const allConfigs = await getAllDocuments(CALENDAR_CONFIG_COLLECTION);
    
    return allConfigs
      .filter(config => {
        const configId = config.id || config.date;
        if (!configId) return false;
        
        // If config has date field, use it; otherwise parse ID
        let configDate;
        if (config.date) {
          configDate = config.date instanceof Timestamp 
            ? config.date.toDate() 
            : new Date(config.date);
        } else {
          // Parse YYYY-MM-DD format
          configDate = new Date(configId);
        }
        
        return configDate >= startDate && configDate <= endDate;
      })
      .map(config => ({
        id: config.id,
        date: config.date ? timestampToDate(config.date) : new Date(config.id),
        maxSlots: config.maxSlots || null,
        isClosed: config.isClosed || false,
        customNote: config.customNote || null,
        reason: config.reason || null,
        lastUpdated: config.lastUpdated ? timestampToDate(config.lastUpdated) : null
      }));
  } catch (error) {
    console.error('Error getting calendar configs in range:', error);
    throw error;
  }
};

/**
 * Get calendar configurations for a specific month
 * @param {number} month - Month (0-11)
 * @param {number} year - Year
 * @returns {Promise<Array>} Array of calendar configs for the month
 */
export const getCalendarConfigsForMonth = async (month, year) => {
  try {
    const startDate = new Date(year, month, 1);
    const endDate = new Date(year, month + 1, 0);
    return await getCalendarConfigsInRange(startDate, endDate);
  } catch (error) {
    console.error('Error getting calendar configs for month:', error);
    throw error;
  }
};

/**
 * Create or update calendar configuration for a date
 * @param {Date|string} date - Date to configure
 * @param {Object} config - Configuration { maxSlots, isClosed, customNote, reason }
 * @returns {Promise<void>}
 */
export const setCalendarConfigForDate = async (date, config) => {
  try {
    // Format date as YYYY-MM-DD
    let dateStr;
    let dateObj;
    if (date instanceof Date) {
      dateObj = date;
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      dateStr = `${year}-${month}-${day}`;
    } else {
      dateStr = date;
      dateObj = new Date(dateStr);
    }
    
    const dataToSave = {
      date: dateToTimestamp(dateObj),
      lastUpdated: Timestamp.now()
    };
    
    if (config.maxSlots !== undefined && config.maxSlots !== null) {
      dataToSave.maxSlots = config.maxSlots;
    }
    if (config.isClosed !== undefined) {
      dataToSave.isClosed = config.isClosed;
    }
    if (config.customNote !== undefined && config.customNote !== null) {
      dataToSave.customNote = config.customNote;
    }
    if (config.reason !== undefined && config.reason !== null) {
      dataToSave.reason = config.reason;
    }
    
    // Use setDoc to create or update (it will create if doesn't exist, update if exists)
    const docRef = doc(db, CALENDAR_CONFIG_COLLECTION, dateStr);
    await setDoc(docRef, dataToSave, { merge: true });
  } catch (error) {
    console.error('Error setting calendar config for date:', error);
    throw error;
  }
};

/**
 * Delete calendar configuration for a date
 * @param {Date|string} date - Date to delete configuration for
 * @returns {Promise<void>}
 */
export const deleteCalendarConfigForDate = async (date) => {
  try {
    // Format date as YYYY-MM-DD
    let dateStr;
    if (date instanceof Date) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      dateStr = `${year}-${month}-${day}`;
    } else {
      dateStr = date;
    }
    
    await deleteDocument(CALENDAR_CONFIG_COLLECTION, dateStr);
  } catch (error) {
    console.error('Error deleting calendar config for date:', error);
    throw error;
  }
};

/**
 * Get max slots for a specific date
 * Uses calendar_config if available, otherwise falls back to system_settings default
 * @param {Date|string} date - Date to get max slots for
 * @returns {Promise<number>} Maximum slots for the date
 */
export const getMaxSlotsForDate = async (date) => {
  try {
    const dateConfig = await getCalendarConfigForDate(date);
    if (dateConfig && dateConfig.maxSlots !== null && dateConfig.maxSlots !== undefined) {
      return dateConfig.maxSlots;
    }
    
    // Fall back to default from system settings
    const settings = await getCalendarSettings();
    return settings.defaultMaxSlots;
  } catch (error) {
    console.error('Error getting max slots for date:', error);
    // Return default if error
    const settings = await getCalendarSettings();
    return settings.defaultMaxSlots;
  }
};

/**
 * Check if a date is closed
 * @param {Date|string} date - Date to check
 * @returns {Promise<boolean>} True if date is closed
 */
export const isDateClosed = async (date) => {
  try {
    const dateConfig = await getCalendarConfigForDate(date);
    return dateConfig ? (dateConfig.isClosed || false) : false;
  } catch (error) {
    console.error('Error checking if date is closed:', error);
    return false;
  }
};

/**
 * Format date as YYYY-MM-DD for use as document ID
 * @param {Date} date - Date to format
 * @returns {string} Formatted date string
 */
const formatDateForId = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

/**
 * Subscribe to calendar configurations for a date range
 * @param {Function} callback - Callback function
 * @param {Date} startDate - Start date
 * @param {Date} endDate - End date
 * @returns {Function} Unsubscribe function
 */
export const subscribeToCalendarConfigs = (callback, startDate, endDate) => {
  try {
    return subscribeToCollection(CALENDAR_CONFIG_COLLECTION, (configs) => {
      const filtered = configs.filter(config => {
        const configDate = config.date 
          ? (config.date instanceof Timestamp ? config.date.toDate() : new Date(config.date))
          : new Date(config.id);
        return configDate >= startDate && configDate <= endDate;
      });
      
      const formatted = filtered.map(config => ({
        id: config.id,
        date: config.date ? timestampToDate(config.date) : new Date(config.id),
        maxSlots: config.maxSlots || null,
        isClosed: config.isClosed || false,
        customNote: config.customNote || null,
        reason: config.reason || null,
        lastUpdated: config.lastUpdated ? timestampToDate(config.lastUpdated) : null
      }));
      
      callback(formatted);
    });
  } catch (error) {
    console.error('Error setting up calendar config listener:', error);
    throw error;
  }
};

