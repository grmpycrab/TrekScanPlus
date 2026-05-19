import React, { useState, useEffect } from 'react';
import { 
  getAllBookings 
} from '../../services/bookingService';
import { 
  getCalendarConfigForDate,
  setCalendarConfigForDate,
  getCalendarConfigsForMonth,
  deleteCalendarConfigForDate,
  getCalendarSettings,
  updateCalendarSettings
} from '../../services/calendarService';
import { Timestamp } from 'firebase/firestore';
import { useToast, ToastContainer } from '../../components/Toast';
import '../style/Utility.css';
import { 
  CalendarToday, 
  Event, 
  Note, 
  People, 
  Add, 
  Delete, 
  Edit,
  CheckCircle,
  Warning,
  Close
} from '@mui/icons-material';

function Utility() {
  const [loading, setLoading] = useState(true);
  const [approvedDates, setApprovedDates] = useState([]); // Dates with approved bookings
  const [calendarConfigs, setCalendarConfigs] = useState([]);
  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth());
  const [currentYear, setCurrentYear] = useState(new Date().getFullYear());
  
  // Form states
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingConfig, setEditingConfig] = useState(null);
  const [formData, setFormData] = useState({
    date: '',
    isClosed: false,
    maxSlots: 30,
    customNote: '',
    reason: ''
  });
  
  // Calendar picker state
  const [calendarPickerMonth, setCalendarPickerMonth] = useState(new Date().getMonth());
  const [calendarPickerYear, setCalendarPickerYear] = useState(new Date().getFullYear());
  
  // Calendar settings
  const [calendarSettings, setCalendarSettings] = useState(null);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [settingsFormData, setSettingsFormData] = useState({
    defaultMaxSlots: 30,
    advanceBookingDays: 1825,
    allowWeekendBookings: true,
    criticalThreshold: 5
  });

  const { toasts, removeToast, success, error: showError, warning, info } = useToast();

  // Fetch approved booking dates
  useEffect(() => {
    const fetchApprovedDates = async () => {
      try {
        const bookings = await getAllBookings({ status: 'approved' });
        const dates = new Set();
        
        bookings.forEach(booking => {
          if (booking.trekDate) {
            const date = booking.trekDate instanceof Timestamp 
              ? booking.trekDate.toDate() 
              : new Date(booking.trekDate);
            
            // Normalize to YYYY-MM-DD
            const dateStr = formatDateKey(date);
            dates.add(dateStr);
          }
        });
        
        setApprovedDates(Array.from(dates));
      } catch (error) {
        console.error('Error fetching approved dates:', error);
        
        // Handle Firestore index error
        if (error.code === 'failed-precondition' && error.message && error.message.includes('index')) {
          let indexUrl = error.indexUrl;
          if (!indexUrl && error.message) {
            const urlPattern = /https:\/\/console\.firebase\.google\.com[^\s\)]+/;
            const urlMatch = error.message.match(urlPattern);
            indexUrl = urlMatch ? urlMatch[0] : null;
          }
          
          if (indexUrl) {
            const indexMessage = '⚠️ Firestore index required to fetch approved booking dates. Click the button below to create it.';
            showError(indexMessage, 20000, {
              label: '🔗 Create Index',
              onClick: () => {
                window.open(indexUrl, '_blank');
                console.log('Opening index creation URL:', indexUrl);
              }
            });
            
            // Log detailed instructions
            console.error('═══════════════════════════════════════════════════════');
            console.error('🔴 Firestore Index Required');
            console.error('═══════════════════════════════════════════════════════');
            console.error('To fetch approved booking dates, Firestore needs a composite index.');
            console.error('');
            console.error('📋 Index Details:');
            console.error('  Collection: bookings');
            console.error('  Fields:');
            console.error('    - status (Ascending)');
            console.error('    - createdAt (Ascending)');
            console.error('');
            console.error('🔗 Create Index URL:');
            console.error(indexUrl);
            console.error('');
            console.error('💡 Instructions:');
            console.error('1. Click the "Create Index" button in the error notification');
            console.error('2. Or copy the URL above and open it in your browser');
            console.error('3. Click "Create Index" in the Firebase Console');
            console.error('4. Wait for the index to build (usually takes a few minutes)');
            console.error('5. Refresh this page once the index is ready');
            console.error('═══════════════════════════════════════════════════════');
            
            // Store URL in a global variable for easy access
            try {
              window.firebaseIndexUrl = indexUrl;
              console.error('💡 TIP: The URL is also stored in window.firebaseIndexUrl');
              console.error('   You can copy it by running: copy(window.firebaseIndexUrl)');
            } catch (e) {
              // Ignore if can't store
            }
          } else {
            const indexMessage = '⚠️ Firestore index required. Please create a composite index:\n- Collection: bookings\n- Fields: status (Ascending), createdAt (Ascending)';
            showError(indexMessage, 15000);
            
            console.error('📝 Manual Index Creation:');
            console.error('1. Go to Firebase Console → Firestore → Indexes');
            console.error('2. Click "Create Index"');
            console.error('3. Collection: bookings');
            console.error('4. Add field: status (Ascending)');
            console.error('5. Add field: createdAt (Ascending)');
            console.error('6. Click "Create"');
          }
        } else {
          showError('Failed to fetch approved booking dates');
        }
      }
    };

    fetchApprovedDates();
  }, []);

  // Fetch calendar configs and settings
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const [configs, settings] = await Promise.all([
          getCalendarConfigsForMonth(currentMonth, currentYear),
          getCalendarSettings()
        ]);
        
        setCalendarConfigs(configs);
        setCalendarSettings(settings);
        
        if (settings) {
          setSettingsFormData({
            defaultMaxSlots: settings.defaultMaxSlots || 30,
            advanceBookingDays: settings.advanceBookingDays || 1825,
            allowWeekendBookings: settings.allowWeekendBookings !== undefined ? settings.allowWeekendBookings : true,
            criticalThreshold: settings.criticalThreshold || 5
          });
        }
      } catch (error) {
        console.error('Error fetching calendar data:', error);
        showError('Failed to fetch calendar configurations');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [currentMonth, currentYear]);

  const formatDateKey = (date) => {
    const d = date instanceof Date ? date : new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const getDaysInMonth = (month, year) => {
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startingDayOfWeek = firstDay.getDay();
    return { daysInMonth, startingDayOfWeek };
  };

  const handleCalendarDateClick = (day) => {
    const dateStr = `${calendarPickerYear}-${String(calendarPickerMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    setFormData({ ...formData, date: dateStr });
  };

  const navigateCalendarMonth = (direction) => {
    if (direction === 'prev') {
      if (calendarPickerMonth === 0) {
        setCalendarPickerMonth(11);
        setCalendarPickerYear(calendarPickerYear - 1);
      } else {
        setCalendarPickerMonth(calendarPickerMonth - 1);
      }
    } else {
      if (calendarPickerMonth === 11) {
        setCalendarPickerMonth(0);
        setCalendarPickerYear(calendarPickerYear + 1);
      } else {
        setCalendarPickerMonth(calendarPickerMonth + 1);
      }
    }
  };

  const getConfigForCalendarDate = (day) => {
    const dateStr = `${calendarPickerYear}-${String(calendarPickerMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    return calendarConfigs.find(config => formatDateKey(config.date) === dateStr);
  };

  const formatDateDisplay = (dateStr) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { 
      weekday: 'short',
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  const isApprovedDate = (dateStr) => {
    return approvedDates.includes(dateStr);
  };

  const handleAddClick = () => {
    setEditingConfig(null);
    const today = new Date();
    setCalendarPickerMonth(today.getMonth());
    setCalendarPickerYear(today.getFullYear());
    setFormData({
      date: '',
      isClosed: false,
      maxSlots: 30,
      customNote: '',
      reason: ''
    });
    setShowAddModal(true);
  };

  const handleEditClick = (config) => {
    setEditingConfig(config);
    const dateStr = formatDateKey(config.date);
    const date = new Date(config.date);
    setCalendarPickerMonth(date.getMonth());
    setCalendarPickerYear(date.getFullYear());
    setFormData({
      date: dateStr,
      isClosed: config.isClosed || false,
      maxSlots: config.maxSlots || 30,
      customNote: config.customNote || '',
      reason: config.reason || ''
    });
    setShowAddModal(true);
  };

  const handleDeleteClick = async (config) => {
    if (!window.confirm(`Are you sure you want to delete the configuration for ${formatDateDisplay(formatDateKey(config.date))}?`)) {
      return;
    }

    try {
      await deleteCalendarConfigForDate(config.date);
      success('Configuration deleted successfully');
      
      // Refresh configs
      const configs = await getCalendarConfigsForMonth(currentMonth, currentYear);
      setCalendarConfigs(configs);
    } catch (error) {
      console.error('Error deleting config:', error);
      showError('Failed to delete configuration');
    }
  };

  const handleFormSubmit = async (e) => {
    e.preventDefault();

    // Validate date
    if (!formData.date) {
      showError('Please select a date');
      return;
    }

    // Check if date has approved bookings (only for new configs or when closing)
    if ((!editingConfig || formData.isClosed) && isApprovedDate(formData.date)) {
      showError('Cannot add buffer date or close date with approved bookings');
      return;
    }

    // Validate max slots
    if (formData.maxSlots < 30 || formData.maxSlots > 45) {
      showError('Maximum trekkers per day must be between 30 and 45');
      return;
    }

    try {
      const dateObj = new Date(formData.date);
      const config = {
        isClosed: formData.isClosed,
        maxSlots: formData.maxSlots,
        customNote: formData.customNote.trim() || null,
        reason: formData.reason.trim() || null
      };

      await setCalendarConfigForDate(dateObj, config);
      
      success(editingConfig ? 'Configuration updated successfully' : 'Configuration added successfully');
      setShowAddModal(false);
      
      // Refresh configs
      const configs = await getCalendarConfigsForMonth(currentMonth, currentYear);
      setCalendarConfigs(configs);
    } catch (error) {
      console.error('Error saving config:', error);
      showError('Failed to save configuration');
    }
  };

  const handleSettingsSubmit = async (e) => {
    e.preventDefault();

    // Validate default max slots
    if (settingsFormData.defaultMaxSlots < 30 || settingsFormData.defaultMaxSlots > 45) {
      showError('Default maximum trekkers must be between 30 and 45');
      return;
    }

    try {
      await updateCalendarSettings(settingsFormData);
      success('Calendar settings updated successfully');
      setShowSettingsModal(false);
      
      // Refresh settings
      const settings = await getCalendarSettings();
      setCalendarSettings(settings);
    } catch (error) {
      console.error('Error updating settings:', error);
      showError('Failed to update calendar settings');
    }
  };

  const handleMonthChange = (direction) => {
    if (direction === 'prev') {
      if (currentMonth === 0) {
        setCurrentMonth(11);
        setCurrentYear(currentYear - 1);
      } else {
        setCurrentMonth(currentMonth - 1);
      }
    } else {
      if (currentMonth === 11) {
        setCurrentMonth(0);
        setCurrentYear(currentYear + 1);
      } else {
        setCurrentMonth(currentMonth + 1);
      }
    }
  };

  const getConfigType = (config) => {
    if (config.isClosed) return 'Closed';
    if (config.maxSlots && config.maxSlots !== 30) return `Max: ${config.maxSlots}`;
    if (config.customNote || config.reason) return 'Event';
    return 'Default';
  };

  return (
    <div className="utility-main">
      <div className="utility-header">
        <div className="utility-header-left">
          <h1 className="utility-title">Utility Management</h1>
          <p className="utility-subtitle">Manage buffer dates, events, notes, and maximum trekkers per day</p>
        </div>
        <div className="utility-header-actions">
          <button 
            className="utility-btn utility-btn-secondary"
            onClick={() => setShowSettingsModal(true)}
          >
            <Event /> Calendar Settings
          </button>
          <button 
            className="utility-btn utility-btn-primary"
            onClick={handleAddClick}
          >
            <Add /> Add Configuration
          </button>
        </div>
      </div>

      {/* Month Navigation */}
      <div className="utility-month-nav">
        <button 
          className="utility-nav-btn"
          onClick={() => handleMonthChange('prev')}
        >
          ← Previous
        </button>
        <h2 className="utility-month-title">
          {new Date(currentYear, currentMonth).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
        </h2>
        <button 
          className="utility-nav-btn"
          onClick={() => handleMonthChange('next')}
        >
          Next →
        </button>
      </div>

      {/* Configurations List */}
      {loading ? (
        <div className="utility-loading">
          <div className="loading-spinner"></div>
          <p>Loading configurations...</p>
        </div>
      ) : (
        <div className="utility-configs-list">
          {calendarConfigs.length === 0 ? (
            <div className="utility-empty">
              <CalendarToday sx={{ fontSize: 64, color: '#9ca3af' }} />
              <p>No configurations for this month</p>
              <button 
                className="utility-btn utility-btn-primary"
                onClick={handleAddClick}
              >
                <Add /> Add First Configuration
              </button>
            </div>
          ) : (
            <div className="utility-configs-grid">
              {calendarConfigs.map((config) => {
                const dateStr = formatDateKey(config.date);
                const hasApproved = isApprovedDate(dateStr);
                
                return (
                  <div 
                    key={config.id || dateStr} 
                    className={`utility-config-card ${config.isClosed ? 'closed' : ''} ${hasApproved ? 'has-approved' : ''}`}
                  >
                    <div className="utility-config-header">
                      <div className="utility-config-date">
                        <CalendarToday sx={{ fontSize: 20 }} />
                        <span>{formatDateDisplay(dateStr)}</span>
                      </div>
                      <div className="utility-config-type">
                        {getConfigType(config)}
                      </div>
                    </div>
                    
                    {hasApproved && (
                      <div className="utility-config-warning">
                        <Warning sx={{ fontSize: 16 }} />
                        <span>Has approved bookings</span>
                      </div>
                    )}
                    
                    <div className="utility-config-details">
                      {config.isClosed && (
                        <div className="utility-config-detail">
                          <Close sx={{ fontSize: 16, color: '#ef4444' }} />
                          <span>Date is closed</span>
                        </div>
                      )}
                      
                      {config.maxSlots && config.maxSlots !== 30 && (
                        <div className="utility-config-detail">
                          <People sx={{ fontSize: 16 }} />
                          <span>Max trekkers: {config.maxSlots}</span>
                        </div>
                      )}
                      
                      {config.reason && (
                        <div className="utility-config-detail">
                          <Event sx={{ fontSize: 16 }} />
                          <span>{config.reason}</span>
                        </div>
                      )}
                      
                      {config.customNote && (
                        <div className="utility-config-detail">
                          <Note sx={{ fontSize: 16 }} />
                          <span>{config.customNote}</span>
                        </div>
                      )}
                    </div>
                    
                    <div className="utility-config-actions">
                      <button 
                        className="utility-action-btn utility-action-edit"
                        onClick={() => handleEditClick(config)}
                        disabled={hasApproved && config.isClosed}
                        title={hasApproved && config.isClosed ? 'Cannot edit closed date with approved bookings' : 'Edit'}
                      >
                        <Edit sx={{ fontSize: 16 }} />
                      </button>
                      <button 
                        className="utility-action-btn utility-action-delete"
                        onClick={() => handleDeleteClick(config)}
                        disabled={hasApproved}
                        title={hasApproved ? 'Cannot delete date with approved bookings' : 'Delete'}
                      >
                        <Delete sx={{ fontSize: 16 }} />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* Add/Edit Modal */}
      {showAddModal && (
        <div className="utility-modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="utility-modal" onClick={(e) => e.stopPropagation()}>
            <div className="utility-modal-header">
              <h2>{editingConfig ? 'Edit Configuration' : 'Add Configuration'}</h2>
              <button 
                className="utility-modal-close"
                onClick={() => setShowAddModal(false)}
              >
                <Close />
              </button>
            </div>
            
            <form className="utility-form" onSubmit={handleFormSubmit}>
              <div className="utility-form-group">
                <label htmlFor="date">Date *</label>
                <input
                  type="date"
                  id="date"
                  value={formData.date}
                  onChange={(e) => {
                    const newDate = e.target.value;
                    setFormData({ ...formData, date: newDate });
                    if (newDate) {
                      const date = new Date(newDate);
                      setCalendarPickerMonth(date.getMonth());
                      setCalendarPickerYear(date.getFullYear());
                    }
                  }}
                  required
                  disabled={!!editingConfig}
                  className={isApprovedDate(formData.date) ? 'has-error' : ''}
                />
                {isApprovedDate(formData.date) && (
                  <div className="utility-form-error">
                    <Warning sx={{ fontSize: 16 }} />
                    This date has approved bookings and cannot be used as a buffer date
                  </div>
                )}
              </div>

              {/* Calendar Picker */}
              <div className="utility-calendar-picker">
                <div className="utility-calendar-header">
                  <button 
                    type="button"
                    className="utility-calendar-nav-btn"
                    onClick={() => navigateCalendarMonth('prev')}
                  >
                    ←
                  </button>
                  <h3 className="utility-calendar-month">
                    {new Date(calendarPickerYear, calendarPickerMonth).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
                  </h3>
                  <button 
                    type="button"
                    className="utility-calendar-nav-btn"
                    onClick={() => navigateCalendarMonth('next')}
                  >
                    →
                  </button>
                </div>
                <div className="utility-calendar-grid">
                  <div className="utility-calendar-weekdays">
                    {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
                      <div key={day} className="utility-calendar-weekday">{day}</div>
                    ))}
                  </div>
                  <div className="utility-calendar-days">
                    {(() => {
                      const { daysInMonth, startingDayOfWeek } = getDaysInMonth(calendarPickerMonth, calendarPickerYear);
                      const days = [];
                      const year = calendarPickerYear;
                      const month = calendarPickerMonth;
                      
                      // Previous month's days
                      const prevMonth = new Date(year, month, 0);
                      const prevMonthDays = prevMonth.getDate();
                      for (let i = startingDayOfWeek - 1; i >= 0; i--) {
                        const day = prevMonthDays - i;
                        days.push(
                          <div key={`prev-${day}`} className="utility-calendar-day utility-calendar-day-other">
                            {day}
                          </div>
                        );
                      }
                      
                      // Current month's days
                      for (let day = 1; day <= daysInMonth; day++) {
                        const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
                        const config = getConfigForCalendarDate(day);
                        const hasApproved = isApprovedDate(dateStr);
                        const isSelected = formData.date === dateStr;
                        const isToday = dateStr === formatDateKey(new Date());
                        const isPast = new Date(dateStr) < new Date(new Date().setHours(0, 0, 0, 0));
                        
                        let dayClass = 'utility-calendar-day';
                        if (isSelected) dayClass += ' utility-calendar-day-selected';
                        if (hasApproved) dayClass += ' utility-calendar-day-approved';
                        if (config?.isClosed) dayClass += ' utility-calendar-day-closed';
                        if (config && !config.isClosed) dayClass += ' utility-calendar-day-has-config';
                        if (isToday) dayClass += ' utility-calendar-day-today';
                        if (isPast) dayClass += ' utility-calendar-day-past';
                        
                        days.push(
                          <div
                            key={day}
                            className={dayClass}
                            onClick={() => !editingConfig && !isPast && handleCalendarDateClick(day)}
                            title={
                              hasApproved ? 'Has approved bookings' :
                              config?.isClosed ? `Closed: ${config.reason || 'No bookings'}` :
                              config ? `Has configuration (Max: ${config.maxSlots || 30})` :
                              'Available'
                            }
                          >
                            {day}
                            {config?.isClosed && (
                              <span className="utility-calendar-day-indicator utility-calendar-day-closed-indicator">×</span>
                            )}
                            {hasApproved && !config?.isClosed && (
                              <span className="utility-calendar-day-indicator utility-calendar-day-approved-indicator">!</span>
                            )}
                            {config && !config.isClosed && !hasApproved && (
                              <span className="utility-calendar-day-indicator utility-calendar-day-config-indicator">•</span>
                            )}
                          </div>
                        );
                      }
                      
                      // Next month's days
                      const totalCells = days.length;
                      const remainingCells = 42 - totalCells; // 6 rows × 7 days
                      for (let day = 1; day <= remainingCells; day++) {
                        days.push(
                          <div key={`next-${day}`} className="utility-calendar-day utility-calendar-day-other">
                            {day}
                          </div>
                        );
                      }
                      
                      return days;
                    })()}
                  </div>
                </div>
                <div className="utility-calendar-legend">
                  <div className="utility-calendar-legend-item">
                    <span className="utility-calendar-legend-color utility-calendar-legend-today"></span>
                    <span>Today</span>
                  </div>
                  <div className="utility-calendar-legend-item">
                    <span className="utility-calendar-legend-color utility-calendar-legend-config"></span>
                    <span>Has Config</span>
                  </div>
                  <div className="utility-calendar-legend-item">
                    <span className="utility-calendar-legend-color utility-calendar-legend-closed"></span>
                    <span>Closed</span>
                  </div>
                  <div className="utility-calendar-legend-item">
                    <span className="utility-calendar-legend-color utility-calendar-legend-approved"></span>
                    <span>Has Approved</span>
                  </div>
                </div>
              </div>

              <div className="utility-form-group">
                <label className="utility-checkbox-label">
                  <input
                    type="checkbox"
                    checked={formData.isClosed}
                    onChange={(e) => setFormData({ ...formData, isClosed: e.target.checked })}
                    disabled={isApprovedDate(formData.date)}
                  />
                  <span>Close this date (prevent bookings)</span>
                </label>
                {isApprovedDate(formData.date) && formData.isClosed && (
                  <div className="utility-form-error">
                    Cannot close date with approved bookings
                  </div>
                )}
              </div>

              <div className="utility-form-group">
                <label htmlFor="maxSlots">Maximum Trekkers Per Day *</label>
                <input
                  type="number"
                  id="maxSlots"
                  min="30"
                  max="45"
                  value={formData.maxSlots}
                  onChange={(e) => setFormData({ ...formData, maxSlots: parseInt(e.target.value) || 30 })}
                  required
                />
                <small>Range: 30-45 trekkers (default: 30)</small>
              </div>

              <div className="utility-form-group">
                <label htmlFor="reason">Event/Reason</label>
                <input
                  type="text"
                  id="reason"
                  value={formData.reason}
                  onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
                  placeholder="e.g., Special Event, Maintenance Day"
                />
              </div>

              <div className="utility-form-group">
                <label htmlFor="customNote">Custom Note</label>
                <textarea
                  id="customNote"
                  value={formData.customNote}
                  onChange={(e) => setFormData({ ...formData, customNote: e.target.value })}
                  placeholder="Additional notes or information..."
                  rows="4"
                />
              </div>

              <div className="utility-form-actions">
                <button 
                  type="button"
                  className="utility-btn utility-btn-secondary"
                  onClick={() => setShowAddModal(false)}
                >
                  Cancel
                </button>
                <button 
                  type="submit"
                  className="utility-btn utility-btn-primary"
                  disabled={isApprovedDate(formData.date) && (!editingConfig || formData.isClosed)}
                >
                  {editingConfig ? 'Update' : 'Add'} Configuration
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Settings Modal */}
      {showSettingsModal && (
        <div className="utility-modal-overlay" onClick={() => setShowSettingsModal(false)}>
          <div className="utility-modal" onClick={(e) => e.stopPropagation()}>
            <div className="utility-modal-header">
              <h2>Calendar Settings</h2>
              <button 
                className="utility-modal-close"
                onClick={() => setShowSettingsModal(false)}
              >
                <Close />
              </button>
            </div>
            
            <form className="utility-form" onSubmit={handleSettingsSubmit}>
              <div className="utility-form-group">
                <label htmlFor="defaultMaxSlots">Default Maximum Trekkers Per Day *</label>
                <input
                  type="number"
                  id="defaultMaxSlots"
                  min="30"
                  max="45"
                  value={settingsFormData.defaultMaxSlots}
                  onChange={(e) => setSettingsFormData({ ...settingsFormData, defaultMaxSlots: parseInt(e.target.value) || 30 })}
                  required
                />
                <small>Default value when no date-specific configuration exists (Range: 30-45)</small>
              </div>

              <div className="utility-form-group">
                <label htmlFor="advanceBookingDays">Advance Booking Days</label>
                <input
                  type="number"
                  id="advanceBookingDays"
                  min="1"
                  value={settingsFormData.advanceBookingDays}
                  onChange={(e) => setSettingsFormData({ ...settingsFormData, advanceBookingDays: parseInt(e.target.value) || 1825 })}
                />
                <small>Maximum days in advance bookings can be made (default: 1825 days / 5 years)</small>
              </div>

              <div className="utility-form-group">
                <label htmlFor="criticalThreshold">Critical Threshold</label>
                <input
                  type="number"
                  id="criticalThreshold"
                  min="1"
                  value={settingsFormData.criticalThreshold}
                  onChange={(e) => setSettingsFormData({ ...settingsFormData, criticalThreshold: parseInt(e.target.value) || 5 })}
                />
                <small>Number of remaining slots to show as "critical" (default: 5)</small>
              </div>

              <div className="utility-form-group">
                <label className="utility-checkbox-label">
                  <input
                    type="checkbox"
                    checked={settingsFormData.allowWeekendBookings}
                    onChange={(e) => setSettingsFormData({ ...settingsFormData, allowWeekendBookings: e.target.checked })}
                  />
                  <span>Allow weekend bookings</span>
                </label>
              </div>

              <div className="utility-form-actions">
                <button 
                  type="button"
                  className="utility-btn utility-btn-secondary"
                  onClick={() => setShowSettingsModal(false)}
                >
                  Cancel
                </button>
                <button 
                  type="submit"
                  className="utility-btn utility-btn-primary"
                >
                  Save Settings
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Toast Notifications */}
      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

export default Utility;

