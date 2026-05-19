import React, { useState, useRef, useEffect, useMemo, useCallback } from 'react';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import AccessTimeIcon from '@mui/icons-material/AccessTime';
import HighlightOffIcon from '@mui/icons-material/HighlightOff';
import TaskAltIcon from '@mui/icons-material/TaskAlt';
import FilterListAltIcon from '@mui/icons-material/FilterListAlt';
import SearchIcon from '@mui/icons-material/Search';
import EventNoteIcon from '@mui/icons-material/EventNote';
import { getAllBookings, updateBookingStatus, subscribeToBookings } from '../../services/bookingService';
import { getUserById } from '../../services/userService';
import { getCurrentUser, onAuthStateChange } from '../../services/firebaseAuthService';
import { 
  getCalendarConfigsForMonth, 
  getCalendarSettings,
  getCalendarConfigForDate 
} from '../../services/calendarService';
import { Timestamp } from 'firebase/firestore';
import '../style/ManageSchedule.css';

function ManageSchedule() {
  const [viewMode, setViewMode] = useState('list'); // 'list' or 'calendar'
  const [currentDate, setCurrentDate] = useState(new Date()); // Current date
  const [selectedDay, setSelectedDay] = useState(null); // null means show all days, number means specific day
  const [selectedFilter, setSelectedFilter] = useState('all'); // 'all', 'completed', 'approve', 'canceled', 'pending'
  const [showFilterDropdown, setShowFilterDropdown] = useState(false);
  const [showMonthYearDropdown, setShowMonthYearDropdown] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [allBookings, setAllBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [calendarConfigs, setCalendarConfigs] = useState({}); // Map of date strings to configs
  const [calendarSettings, setCalendarSettings] = useState(null);
  const filterRef = useRef(null);
  const monthYearRef = useRef(null);

  // Function to automatically mark past approved bookings as completed
  const markPastApprovedBookingsAsCompleted = async (bookings) => {
    const now = new Date();
    // Create a date at midnight for accurate comparison (avoid timezone issues)
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    today.setHours(0, 0, 0, 0);
    
    // Format date in local timezone (not UTC)
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    
    console.log('🔍 Checking for past approved bookings...');
    console.log('📅 Today\'s date (local):', todayStr);
    
    const updatePromises = [];
    let checkedCount = 0;
    let pastCount = 0;
    
    for (const booking of bookings) {
      // Only check approved bookings
      if (booking.status?.toLowerCase() !== 'approved') {
        continue;
      }
      
      checkedCount++;
      
      // Check if booking has a trekDate
      if (!booking.trekDate) {
        continue;
      }
      
      // Convert trekDate to Date object
      let trekDate;
      if (booking.trekDate instanceof Timestamp) {
        trekDate = booking.trekDate.toDate();
      } else {
        trekDate = new Date(booking.trekDate);
      }
      
      // Create a date at midnight for accurate comparison (using local time to avoid timezone issues)
      const bookingYear = trekDate.getFullYear();
      const bookingMonth = trekDate.getMonth();
      const bookingDay = trekDate.getDate();
      const bookingDate = new Date(bookingYear, bookingMonth, bookingDay);
      bookingDate.setHours(0, 0, 0, 0);
      
      // Compare dates using getTime() for accurate comparison
      const bookingTime = bookingDate.getTime();
      const todayTime = today.getTime();
      
      const bookingDateStr = `${bookingYear}-${String(bookingMonth + 1).padStart(2, '0')}-${String(bookingDay).padStart(2, '0')}`;
      
      console.log(`  Booking ${booking.id}: Status=${booking.status}, TrekDate=${bookingDateStr}, Today=${todayStr}, IsPast=${bookingTime < todayTime}`);
      
      // If trek date is in the past (before today), mark as completed
      if (bookingTime < todayTime) {
        pastCount++;
        console.log(`  ✅ Found past approved booking: ${booking.id} (Date: ${bookingDateStr})`);
        try {
          updatePromises.push(
            updateBookingStatus(booking.id, 'completed')
              .then(() => {
                console.log(`  ✅ Successfully marked booking ${booking.id} as completed`);
              })
              .catch((error) => {
                console.error(`  ❌ Error updating booking ${booking.id} to completed:`, error);
              })
          );
        } catch (error) {
          console.error(`  ❌ Error processing booking ${booking.id}:`, error);
        }
      }
    }
    
    console.log(`📊 Checked ${checkedCount} approved bookings, found ${pastCount} past dates`);
    
    // Wait for all updates to complete
    if (updatePromises.length > 0) {
      console.log(`🔄 Updating ${updatePromises.length} booking(s) to completed status...`);
      const results = await Promise.allSettled(updatePromises);
      const successful = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.filter(r => r.status === 'rejected').length;
      console.log(`✅ Updated ${successful} booking(s), ${failed} failed`);
      
      // Refetch bookings after updates to get the latest status
      try {
        const updatedBookings = await getAllBookings();
        console.log(`🔄 Refetched ${updatedBookings.length} bookings after status updates`);
        return updatedBookings;
      } catch (error) {
        console.error('❌ Error refetching bookings after status updates:', error);
        return bookings; // Return original bookings if refetch fails
      }
    }
    
    return bookings;
  };

  // Fetch bookings and calendar configs from Firebase
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const currentUser = getCurrentUser();
        if (!currentUser) {
          setLoading(false);
          return;
        }

        // Fetch bookings and calendar data in parallel
        const [bookings, settings] = await Promise.all([
          getAllBookings(),
          getCalendarSettings()
        ]);
        
        // Automatically mark past approved bookings as completed
        const updatedBookings = await markPastApprovedBookingsAsCompleted(bookings);
        
        setAllBookings(updatedBookings);
        setCalendarSettings(settings);
      } catch (error) {
        console.error('Error fetching data:', error);
        setAllBookings([]);
        setCalendarSettings(null);
      } finally {
        setLoading(false);
      }
    };

    const unsubscribe = onAuthStateChange((user) => {
      if (user) {
        fetchData();
      } else {
        setAllBookings([]);
        setCalendarSettings(null);
        setLoading(false);
      }
    });

    const currentUser = getCurrentUser();
    if (currentUser) {
      fetchData();
    }

    // Subscribe to real-time booking updates
    let unsubscribeBookings = null;
    if (currentUser) {
      unsubscribeBookings = subscribeToBookings(() => {
        // When bookings change, refetch and check for past approved bookings
        fetchData();
      });
    }

    return () => {
      unsubscribe();
      if (unsubscribeBookings) {
        unsubscribeBookings();
      }
    };
  }, []);

  // Check for past approved bookings when bookings are first loaded
  const bookingsInitialized = useRef(false);
  useEffect(() => {
    const currentUser = getCurrentUser();
    if (!currentUser || allBookings.length === 0) {
      bookingsInitialized.current = false;
      return;
    }

    // Only run once when bookings are first loaded
    if (!bookingsInitialized.current) {
      bookingsInitialized.current = true;
      const checkPastBookings = async () => {
        const updatedBookings = await markPastApprovedBookingsAsCompleted(allBookings);
        if (updatedBookings) {
          setAllBookings(updatedBookings);
        }
      };
      checkPastBookings();
    }
  }, [allBookings.length]); // Run when bookings are loaded

  // Periodic check for past approved bookings (every 5 minutes)
  useEffect(() => {
    const currentUser = getCurrentUser();
    if (!currentUser) return;

    const checkAndUpdateBookings = async () => {
      try {
        const bookings = await getAllBookings();
        const updatedBookings = await markPastApprovedBookingsAsCompleted(bookings);
        if (updatedBookings) {
          setAllBookings(updatedBookings);
        }
      } catch (error) {
        console.error('Error in periodic booking check:', error);
      }
    };

    // Check immediately, then every 5 minutes
    checkAndUpdateBookings();
    const intervalId = setInterval(checkAndUpdateBookings, 5 * 60 * 1000);

    return () => clearInterval(intervalId);
  }, []); // Only run once on mount

  // Fetch calendar configs for current month
  useEffect(() => {
    const fetchCalendarConfigs = async () => {
      try {
        const currentMonth = currentDate.getMonth();
        const currentYear = currentDate.getFullYear();
        const configs = await getCalendarConfigsForMonth(currentMonth, currentYear);
        
        // Convert to map for easy lookup
        const configMap = {};
        configs.forEach(config => {
          const dateKey = formatDateKey(config.date);
          configMap[dateKey] = config;
        });
        
        setCalendarConfigs(configMap);
      } catch (error) {
        console.error('Error fetching calendar configs:', error);
        setCalendarConfigs({});
      }
    };

    if (calendarSettings) {
      fetchCalendarConfigs();
    }
  }, [currentDate, calendarSettings]);

  // Helper function to format date as YYYY-MM-DD key
  const formatDateKey = (date) => {
    if (!date) return '';
    const d = date instanceof Date ? date : new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  // Convert bookings to events format based on trekDate
  const convertBookingsToEvents = async (bookings) => {
    const events = [];
    
    for (const booking of bookings) {
      if (!booking.trekDate) continue;
      
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      
      const day = trekDate.getDate();
      const month = trekDate.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
      
      // Fetch user data for affiliation
      let user = null;
      if (booking.userId) {
        try {
          user = await getUserById(booking.userId);
        } catch (error) {
          console.error('Error fetching user:', error);
        }
      }
      
      // Map status
      let status = 'Upcoming';
      if (booking.status?.toLowerCase() === 'approved') {
        status = 'Active';
      } else if (booking.status?.toLowerCase() === 'completed') {
        status = 'Active'; // Treat completed as active for display
      } else if (booking.status?.toLowerCase() === 'cancelled' || booking.status?.toLowerCase() === 'rejected') {
        status = 'Cancelled';
      }
      
      events.push({
        id: booking.id,
        day: day,
        month: month,
        title: booking.affiliation || (user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown'),
        description: booking.notes || booking.trekType || 'Trek Request',
        location: 'Mt. Hamiguitan',
        participants: booking.numberOfPorters || 1, // Using numberOfPorters as participants
        status: status,
        type: booking.trekType || 'recreational',
        color: '#E9D5FF',
        time: '10:30 - 12:00',
        price: 'Free',
        bookingStatus: booking.status?.toLowerCase() || 'pending',
        trekDate: trekDate
      });
    }
    
    return events;
  };

  // Get events for the current month
  const [events, setEvents] = useState([]);
  
  useEffect(() => {
    const loadEvents = async () => {
      if (allBookings.length === 0) {
        setEvents([]);
        return;
      }
      
      const currentMonth = currentDate.getMonth();
      const currentYear = currentDate.getFullYear();
      
      // Filter bookings by trekDate month/year
      const monthBookings = allBookings.filter(booking => {
        if (!booking.trekDate) return false;
        
        const trekDate = booking.trekDate instanceof Timestamp 
          ? booking.trekDate.toDate() 
          : new Date(booking.trekDate);
        
        return trekDate.getMonth() === currentMonth && trekDate.getFullYear() === currentYear;
      });
      
      const convertedEvents = await convertBookingsToEvents(monthBookings);
      setEvents(convertedEvents);
    };
    
    loadEvents();
  }, [allBookings, currentDate]);

  // Create a map of userId to user data for quick lookup
  const [usersMap, setUsersMap] = useState(new Map());
  
  useEffect(() => {
    const fetchUsers = async () => {
      if (allBookings.length === 0) {
        setUsersMap(new Map());
        return;
      }
      
      const uniqueUserIds = [...new Set(allBookings.map(b => b.userId).filter(Boolean))];
      const userMap = new Map();
      
      await Promise.all(
        uniqueUserIds.map(async (userId) => {
          try {
            const user = await getUserById(userId);
            if (user) {
              userMap.set(userId, user);
            }
          } catch (error) {
            console.error('Error fetching user:', userId, error);
          }
        })
      );
      
      setUsersMap(userMap);
    };
    
    fetchUsers();
  }, [allBookings]);

  // Get past events (bookings with trekDate in the past)
  const pastEvents = useMemo(() => {
    const now = new Date();
    return allBookings
      .filter(booking => {
        if (!booking.trekDate) return false;
        const trekDate = booking.trekDate instanceof Timestamp 
          ? booking.trekDate.toDate() 
          : new Date(booking.trekDate);
        return trekDate < now;
      })
      .slice(0, 10) // Limit to 10 most recent
      .map(booking => {
        const trekDate = booking.trekDate instanceof Timestamp 
          ? booking.trekDate.toDate() 
          : new Date(booking.trekDate);
        return {
          id: booking.id,
          day: trekDate.getDate(),
          month: trekDate.toLocaleDateString('en-US', { month: 'short' }).toUpperCase(),
          year: trekDate.getFullYear(),
          title: booking.affiliation || 'Trek Request',
          description: booking.notes || booking.trekType || 'Trek Request',
          date: trekDate.toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' })
        };
      });
  }, [allBookings]);

  const getDaysInMonth = (date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startingDayOfWeek = firstDay.getDay();
    
    return { daysInMonth, startingDayOfWeek };
  };

  const navigateMonth = (direction) => {
    setCurrentDate(prev => {
      const newDate = new Date(prev);
      if (direction === 'prev') {
        newDate.setMonth(prev.getMonth() - 1);
      } else {
        newDate.setMonth(prev.getMonth() + 1);
      }
      setSelectedDay(null); // Reset selected day when changing months to show all bookings
      return newDate;
    });
  };

  // Memoize getEventsForDay to ensure stable results - never filter by selectedDay for calendar display
  const getEventsForDay = useCallback((day) => {
    const currentMonth = currentDate.getMonth();
    const currentYear = currentDate.getFullYear();
    
    // Always use the full allBookings array - never filter by selectedDay for calendar display
    // selectedDay should only affect the list view, not the calendar numbers
    return allBookings.filter(booking => {
      if (!booking.trekDate) return false;
      
      // Exclude cancelled and rejected bookings from calendar
      const status = booking.status?.toLowerCase();
      if (status === 'cancelled' || status === 'rejected') {
        return false;
      }
      
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      
      // Normalize dates to midnight for accurate comparison (avoid timezone issues)
      const bookingDate = new Date(trekDate.getFullYear(), trekDate.getMonth(), trekDate.getDate());
      const targetDate = new Date(currentYear, currentMonth, day);
      
      return bookingDate.getTime() === targetDate.getTime();
    });
  }, [allBookings, currentDate]);

  const formatMonthYear = (date) => {
    return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  };

  const formatCurrentDay = (date, day) => {
    if (day === null) {
      return date.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
    }
    const dayDate = new Date(date.getFullYear(), date.getMonth(), day);
    const dayName = dayDate.toLocaleDateString('en-US', { weekday: 'long' });
    const dayNumber = day;
    const suffix = dayNumber === 1 || dayNumber === 21 || dayNumber === 31 ? 'st' :
                   dayNumber === 2 || dayNumber === 22 ? 'nd' :
                   dayNumber === 3 || dayNumber === 23 ? 'rd' : 'th';
    return `${dayName} ${dayNumber}${suffix}`;
  };

  const getDayOfWeek = (date, day) => {
    if (day === null) {
      return new Date().getDay(); // Return current day if no day selected
    }
    const dayDate = new Date(date.getFullYear(), date.getMonth(), day);
    return dayDate.getDay(); // 0 = Sunday, 1 = Monday, etc.
  };

  const handleMonthChange = (e) => {
    const newDate = new Date(currentDate);
    newDate.setMonth(parseInt(e.target.value));
    setCurrentDate(newDate);
    setShowMonthYearDropdown(false);
  };

  const handleYearChange = (e) => {
    const newDate = new Date(currentDate);
    newDate.setFullYear(parseInt(e.target.value));
    setCurrentDate(newDate);
    setShowMonthYearDropdown(false);
  };

  const formatMonthYearDisplay = (date) => {
    return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  };

  const getMonths = () => {
    return [
      { value: 0, label: 'January' },
      { value: 1, label: 'February' },
      { value: 2, label: 'March' },
      { value: 3, label: 'April' },
      { value: 4, label: 'May' },
      { value: 5, label: 'June' },
      { value: 6, label: 'July' },
      { value: 7, label: 'August' },
      { value: 8, label: 'September' },
      { value: 9, label: 'October' },
      { value: 10, label: 'November' },
      { value: 11, label: 'December' }
    ];
  };

  const getYears = () => {
    const years = [];
    const currentYear = new Date().getFullYear();
    for (let i = currentYear - 5; i <= currentYear + 5; i++) {
      years.push(i);
    }
    return years;
  };

  const getFilterLabel = () => {
    switch(selectedFilter) {
      case 'all': return 'All Status';
      case 'completed': return 'Completed';
      case 'approve': return 'Approve';
      case 'canceled': return 'Canceled';
      case 'pending': return 'Pending';
      default: return 'All Status';
    }
  };

  // Calculate event counts by status from real bookings
  const eventCounts = useMemo(() => {
    const currentMonth = currentDate.getMonth();
    const currentYear = currentDate.getFullYear();
    
    // Filter bookings by trekDate month/year
    const monthBookings = allBookings.filter(booking => {
      if (!booking.trekDate) return false;
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      return trekDate.getMonth() === currentMonth && trekDate.getFullYear() === currentYear;
    });
    
    const completed = monthBookings.filter(b => b.status?.toLowerCase() === 'completed').length;
    const pending = monthBookings.filter(b => b.status?.toLowerCase() === 'pending').length;
    const cancelled = monthBookings.filter(b => b.status?.toLowerCase() === 'cancelled' || b.status?.toLowerCase() === 'rejected').length;
    const approved = monthBookings.filter(b => b.status?.toLowerCase() === 'approved').length;
    
    return {
      completed: completed,
      pending: pending,
      cancelled: cancelled,
      approved: approved
    };
  }, [allBookings, currentDate]);
  const totalEvents = eventCounts.completed + eventCounts.pending + eventCounts.cancelled + eventCounts.approved;

  // Calculate slot availability for calendar view from real bookings
  const slotAvailability = useMemo(() => {
    const currentMonth = currentDate.getMonth();
    const currentYear = currentDate.getFullYear();
    
    // Filter bookings by trekDate month/year
    const monthBookings = allBookings.filter(booking => {
      if (!booking.trekDate) return false;
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      return trekDate.getMonth() === currentMonth && trekDate.getFullYear() === currentYear;
    });
    
    // Get default max capacity from calendar settings
    const DEFAULT_MAX_CAPACITY = calendarSettings?.defaultMaxSlots || 30;
    
    let available = 0; // Green - 0-30% booked
    let limited = 0;   // Yellow/Orange - 30-80% booked
    let full = 0;      // Red - 80-100% booked
    
    // Group bookings by day (only count approved/pending bookings)
    const bookingsByDay = {};
    monthBookings.forEach(booking => {
      const status = booking.status?.toLowerCase();
      if (status === 'cancelled' || status === 'rejected') return; // Don't count cancelled/rejected
      
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      const day = trekDate.getDate();
      
      if (!bookingsByDay[day]) {
        bookingsByDay[day] = 0;
      }
      bookingsByDay[day] += (booking.numberOfPorters || 1);
    });
    
    // Count days by availability status (using date-specific maxSlots if available)
    Object.entries(bookingsByDay).forEach(([day, participants]) => {
      const dayNum = parseInt(day);
      const dateKey = formatDateKey(new Date(currentYear, currentMonth, dayNum));
      const dateConfig = calendarConfigs[dateKey];
      
      // Use date-specific maxSlots or default
      const maxCapacity = dateConfig?.maxSlots || DEFAULT_MAX_CAPACITY;
      
      // If date is closed, count as full
      if (dateConfig?.isClosed) {
        full++;
        return;
      }
      
      const percentage = (participants / maxCapacity) * 100;
      if (percentage < 30) {
        available++;
      } else if (percentage < 80) {
        limited++;
      } else {
        full++;
      }
    });
    
    // Count days with no bookings as available
    const { daysInMonth } = getDaysInMonth(currentDate);
    const daysWithBookings = Object.keys(bookingsByDay).length;
    available += (daysInMonth - daysWithBookings);
    
    return { available, limited, full };
  }, [allBookings, currentDate]);

  // Close dropdowns on outside click
  useEffect(() => {
    function handleClickOutside(e) {
      if (filterRef.current && !filterRef.current.contains(e.target)) {
        setShowFilterDropdown(false);
      }
      if (monthYearRef.current && !monthYearRef.current.contains(e.target)) {
        setShowMonthYearDropdown(false);
      }
    }
    if (showFilterDropdown || showMonthYearDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [showFilterDropdown, showMonthYearDropdown]);

  return (
    <div className="manage-schedule-main">
      <div className="event-header">
        <div className="view-toggles">
          <button 
            className={`view-toggle-btn ${viewMode === 'list' ? 'active' : ''}`}
            onClick={() => setViewMode('list')}
          >
            List View
          </button>
          <button 
            className={`view-toggle-btn ${viewMode === 'calendar' ? 'active' : ''}`}
            onClick={() => setViewMode('calendar')}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="4" width="18" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
              <line x1="16" y1="2" x2="16" y2="6" stroke="currentColor" strokeWidth="2"/>
              <line x1="8" y1="2" x2="8" y2="6" stroke="currentColor" strokeWidth="2"/>
              <line x1="3" y1="10" x2="21" y2="10" stroke="currentColor" strokeWidth="2"/>
            </svg>
            Calendar View
          </button>
        </div>
      </div>

      {viewMode === 'list' ? (
        <div>
          {/* Filter Section */}
          <div className="schedule-filters-section">
            <div className="schedule-left-filters">
              <div className="schedule-date-range-selector" ref={monthYearRef}>
                <button 
                  className="month-year-selector-btn"
                  onClick={() => setShowMonthYearDropdown(!showMonthYearDropdown)}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" className="calendar-icon-filter">
                    <rect x="3" y="4" width="18" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
                    <line x1="16" y1="2" x2="16" y2="6" stroke="currentColor" strokeWidth="2"/>
                    <line x1="8" y1="2" x2="8" y2="6" stroke="currentColor" strokeWidth="2"/>
                    <line x1="3" y1="10" x2="21" y2="10" stroke="currentColor" strokeWidth="2"/>
                      </svg>
                  <span className="date-range-text">{formatMonthYearDisplay(currentDate)}</span>
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" className="chevron-down">
                    <path d="M6 9L12 15L18 9" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                </button>
                {showMonthYearDropdown && (
                  <div className="month-year-dropdown-menu">
                    <div className="month-year-selectors">
              <select 
                className="month-selector"
                value={currentDate.getMonth()}
                onChange={handleMonthChange}
              >
                {getMonths().map(month => (
                  <option key={month.value} value={month.value}>{month.label}</option>
                ))}
              </select>
              <select 
                className="year-selector"
                value={currentDate.getFullYear()}
                onChange={handleYearChange}
              >
                {getYears().map(year => (
                  <option key={year} value={year}>{year}</option>
                ))}
              </select>
            </div>
                  </div>
                )}
              </div>
              <div className="schedule-search-container">
                <SearchIcon className="search-icon" />
                <input
                  type="text"
                  className="schedule-search-input"
                  placeholder="Search..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>
            </div>
            <div className="schedule-filters-group" ref={filterRef}>
              <div className="filter-dropdown-container">
                <button 
                  className="filter-dropdown-btn"
                  onClick={() => setShowFilterDropdown(!showFilterDropdown)}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" className="filter-icon">
                    <path d="M4 6H20M4 12H20M4 18H20" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                  </svg>
                  Filters
                </button>
                {showFilterDropdown && (
                  <div className="filter-dropdown-menu">
                    <div className="filter-dropdown-header">FILTER BY STATUS</div>
                    <button 
                      className={`filter-dropdown-item ${selectedFilter === 'all' ? 'active' : ''}`}
                      onClick={() => {
                        setSelectedFilter('all');
                        setSelectedDay(null); // Reset day selection when changing filter
                        setShowFilterDropdown(false);
                      }}
                    >
                      <FilterListAltIcon className="filter-icon-all" />
                      All Status
                    </button>
                    <button 
                      className={`filter-dropdown-item ${selectedFilter === 'completed' ? 'active' : ''}`}
                      data-filter="completed"
                      onClick={() => {
                        setSelectedFilter('completed');
                        setSelectedDay(null); // Reset day selection when changing filter
                        setShowFilterDropdown(false);
                      }}
                    >
                      <CheckCircleIcon className="filter-icon-completed" />
                      Completed
                    </button>
                    <button 
                      className={`filter-dropdown-item ${selectedFilter === 'approve' ? 'active' : ''}`}
                      data-filter="approve"
                      onClick={() => {
                        setSelectedFilter('approve');
                        setSelectedDay(null); // Reset day selection when changing filter
                        setShowFilterDropdown(false);
                      }}
                    >
                      <TaskAltIcon className="filter-icon-approve" />
                      Approve
                    </button>
                    <button 
                      className={`filter-dropdown-item ${selectedFilter === 'canceled' ? 'active' : ''}`}
                      data-filter="canceled"
                      onClick={() => {
                        setSelectedFilter('canceled');
                        setSelectedDay(null); // Reset day selection when changing filter
                        setShowFilterDropdown(false);
                      }}
                    >
                      <HighlightOffIcon className="filter-icon-canceled" />
                      Canceled
                    </button>
                    <button 
                      className={`filter-dropdown-item ${selectedFilter === 'pending' ? 'active' : ''}`}
                      data-filter="pending"
                      onClick={() => {
                        setSelectedFilter('pending');
                        setSelectedDay(null); // Reset day selection when changing filter
                        setShowFilterDropdown(false);
                      }}
                    >
                      <AccessTimeIcon className="filter-icon-pending" />
                      Pending
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="calendar-events-layout">
          {/* Left Column - Calendar */}
          <div className="calendar-left-column">
            <div className="calendar-section">
              <div className="calendar-header-simple">
                <button className="nav-arrow-simple" onClick={() => navigateMonth('prev')}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M15 18L9 12L15 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
                <h3 className="calendar-month-year-text">
                  {formatMonthYear(currentDate)}
                </h3>
                <button className="nav-arrow-simple" onClick={() => navigateMonth('next')}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M9 18L15 12L9 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
              </div>
              
              <div className="calendar-grid-compact">
                <div className="calendar-weekdays-compact">
                  {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
                    <div key={day} className="weekday-compact">{day}</div>
                  ))}
                </div>
                <div className="calendar-days-compact">
                  {(() => {
                    const { daysInMonth, startingDayOfWeek } = getDaysInMonth(currentDate);
                    const days = [];
                    const year = currentDate.getFullYear();
                    const month = currentDate.getMonth();
                    
                    // Get previous month's last day
                    const prevMonth = new Date(year, month, 0);
                    const prevMonthDays = prevMonth.getDate();
                    
                    // JavaScript's getDay() returns 0 for Sunday, 1 for Monday, etc.
                    // Calendar starts on Sunday (0), so no adjustment needed
                    const adjustedStart = startingDayOfWeek;
                    
                    // Days from previous month (fill in the gap before the first day of current month)
                    for (let i = adjustedStart - 1; i >= 0; i--) {
                      const day = prevMonthDays - i;
                      days.push(
                        <div key={`prev-${day}`} className="calendar-day-compact empty">
                          <div className="day-number-compact">{day}</div>
                        </div>
                      );
                    }
                    
                    // Days of the current month
                    for (let day = 1; day <= daysInMonth; day++) {
                      const dayEvents = getEventsForDay(day);
                      const bookingCount = dayEvents.length;
                      const hasEvents = bookingCount > 0;
                      const isSelected = day === selectedDay;
                      
                      // Check calendar config for this day
                      const dateKey = formatDateKey(new Date(year, month, day));
                      const dateConfig = calendarConfigs[dateKey];
                      const isClosed = dateConfig?.isClosed || false;
                      const maxSlots = dateConfig?.maxSlots || calendarSettings?.defaultMaxSlots || 30;
                      
                      // Calculate availability percentage
                      let availabilityClass = '';
                      if (isClosed) {
                        availabilityClass = 'closed';
                      } else if (hasEvents) {
                        const participants = dayEvents.reduce((sum, booking) => sum + (booking.numberOfPorters || 1), 0);
                        const percentage = (participants / maxSlots) * 100;
                        if (percentage >= 80) {
                          availabilityClass = 'full';
                        } else if (percentage >= 30) {
                          availabilityClass = 'limited';
                        } else {
                          availabilityClass = 'available';
                        }
                      } else {
                        availabilityClass = 'available';
                      }
                      
                      days.push(
                        <div 
                          key={day} 
                          className={`calendar-day-compact ${isSelected ? 'selected' : ''} ${hasEvents ? 'has-events' : ''} ${availabilityClass}`}
                          onClick={() => {
                            // Toggle: if same day is clicked, deselect it (show all)
                            if (selectedDay === day) {
                              setSelectedDay(null);
                            } else {
                              setSelectedDay(day);
                            }
                          }}
                          title={isClosed ? `Closed: ${dateConfig?.reason || 'No bookings allowed'}` : 
                                 dateConfig?.customNote ? dateConfig.customNote : 
                                 hasEvents ? `${bookingCount} booking${bookingCount > 1 ? 's' : ''}` : 'Available'}
                        >
                          <div className="day-number-compact">{day}</div>
                          {isClosed && (
                            <div className="closed-indicator-compact" title={dateConfig?.reason || 'Closed'}>
                              <svg width="12" height="12" viewBox="0 0 24 24" fill="none">
                                <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                              </svg>
                            </div>
                          )}
                          {hasEvents && !isClosed && (
                            <div className="booking-count-badge-compact">
                              {bookingCount}
                            </div>
                          )}
                        </div>
                      );
                    }
                    
                    // Fill remaining cells with next month's days to complete the grid (always 7 columns)
                    const totalCells = days.length;
                    const cellsInGrid = Math.ceil(totalCells / 7) * 7;
                    const remainingCells = cellsInGrid - totalCells;
                    for (let i = 1; i <= remainingCells; i++) {
                      days.push(
                        <div key={`next-${i}`} className="calendar-day-compact empty">
                          <div className="day-number-compact">{i}</div>
                        </div>
                      );
                    }
                    
                    return days;
                  })()}
                </div>
              </div>
            </div>
            
            {/* Slot Availability Indicator */}
            <div className="slot-availability-indicator slot-availability-compact">
              <div className="slot-indicator-item">
                <div className="slot-indicator-line available"></div>
                <span className="slot-indicator-label">Available</span>
              </div>
              <div className="slot-indicator-item">
                <div className="slot-indicator-line limited"></div>
                <span className="slot-indicator-label">Limited Slots</span>
              </div>
              <div className="slot-indicator-item">
                <div className="slot-indicator-line full"></div>
                <span className="slot-indicator-label">Full</span>
              </div>
            </div>
            
            {/* Category Buttons */}
            <div className="calendar-categories">
              <h3 className="categories-title">Categories</h3>
              
              {/* Status Cards */}
              <div className="category-status-cards">
                <div className="category-status-left">
                  <button 
                    className={`category-status-card completed ${selectedFilter === 'completed' ? 'active' : ''}`}
                    onClick={() => {
                      setSelectedFilter('completed');
                      setSelectedDay(null); // Reset day selection when changing filter
                    }}
                  >
                    <div className="category-status-icon" style={{ backgroundColor: '#10b981' }}>
                      <CheckCircleIcon style={{ color: '#ffffff', fontSize: '20px' }} />
                    </div>
                    <div className="category-status-info">
                      <div className="category-status-title">Completed</div>
                      <div className="category-status-count">{eventCounts.completed} total bookings</div>
                    </div>
                    <div className="category-status-indicator" style={{ backgroundColor: '#10b981' }}></div>
                  </button>
                  
                  <button 
                    className={`category-status-card canceled ${selectedFilter === 'canceled' ? 'active' : ''}`}
                    onClick={() => {
                      setSelectedFilter('canceled');
                      setSelectedDay(null); // Reset day selection when changing filter
                    }}
                  >
                    <div className="category-status-icon" style={{ backgroundColor: '#ef4444' }}>
                      <HighlightOffIcon style={{ color: '#ffffff', fontSize: '20px' }} />
                    </div>
                    <div className="category-status-info">
                      <div className="category-status-title">Cancelled</div>
                      <div className="category-status-count">{eventCounts.cancelled} total bookings</div>
                    </div>
                    <div className="category-status-indicator" style={{ backgroundColor: '#ef4444' }}></div>
                  </button>
                </div>
                
                <div className="category-status-right">
                  <button 
                    className={`category-status-card pending ${selectedFilter === 'pending' ? 'active' : ''}`}
                    onClick={() => {
                      setSelectedFilter('pending');
                      setSelectedDay(null); // Reset day selection when changing filter
                    }}
                  >
                    <div className="category-status-icon" style={{ backgroundColor: '#f59e0b' }}>
                      <AccessTimeIcon style={{ color: '#ffffff', fontSize: '20px' }} />
                    </div>
                    <div className="category-status-info">
                      <div className="category-status-title">Pending</div>
                      <div className="category-status-count">{eventCounts.pending} total bookings</div>
                    </div>
                    <div className="category-status-indicator" style={{ backgroundColor: '#f59e0b' }}></div>
                  </button>
                  
                  <button 
                    className={`category-status-card approve ${selectedFilter === 'approve' ? 'active' : ''}`}
                    onClick={() => {
                      setSelectedFilter('approve');
                      setSelectedDay(null); // Reset day selection when changing filter
                    }}
                  >
                    <div className="category-status-icon" style={{ backgroundColor: '#3b82f6' }}>
                      <TaskAltIcon style={{ color: '#ffffff', fontSize: '20px' }} />
                    </div>
                    <div className="category-status-info">
                      <div className="category-status-title">Approved</div>
                      <div className="category-status-count">{eventCounts.approved} total bookings</div>
                    </div>
                    <div className="category-status-indicator" style={{ backgroundColor: '#3b82f6' }}></div>
                  </button>
                </div>
              </div>
              
              {/* Summary Card */}
              <div className="category-summary-card">
                <div className="summary-row">
                  <span className="summary-label">Total Bookings</span>
                  <span className="summary-value">{totalEvents}</span>
                </div>
                <div className="progress-bar-container">
                  <div className="progress-bar">
                    <div 
                      className="progress-segment completed" 
                      style={{ width: `${(eventCounts.completed / totalEvents) * 100}%` }}
                    ></div>
                    <div 
                      className="progress-segment pending" 
                      style={{ width: `${(eventCounts.pending / totalEvents) * 100}%` }}
                    ></div>
                    <div 
                      className="progress-segment approved" 
                      style={{ width: `${(eventCounts.approved / totalEvents) * 100}%` }}
                    ></div>
                    <div 
                      className="progress-segment cancelled" 
                      style={{ width: `${(eventCounts.cancelled / totalEvents) * 100}%` }}
                    ></div>
                  </div>
                </div>
                <div className="progress-legend">
                  <div className="legend-left">
                    <div className="legend-item">
                      <div className="legend-dot" style={{ backgroundColor: '#10b981' }}></div>
                      <span>Completed</span>
                    </div>
                    <div className="legend-item">
                      <div className="legend-dot" style={{ backgroundColor: '#ef4444' }}></div>
                      <span>Cancelled</span>
                    </div>
                  </div>
                  <div className="legend-right">
                    <div className="legend-item">
                      <div className="legend-dot" style={{ backgroundColor: '#f59e0b' }}></div>
                      <span>Pending</span>
                    </div>
                    <div className="legend-item">
                      <div className="legend-dot" style={{ backgroundColor: '#3b82f6' }}></div>
                      <span>Approved</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column - Upcoming Events */}
          <div className="events-right-column">
            <div className="upcoming-events-header">
              <button className="nav-arrow-simple" onClick={() => navigateMonth('prev')}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M15 18L9 12L15 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <h3 className="upcoming-events-title">Scheduled Bookings</h3>
              <button className="nav-arrow-simple" onClick={() => navigateMonth('next')}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M9 18L15 12L9 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
            
            <div className="upcoming-events-list">
              {(() => {
                if (loading) {
                  return (
                    <div className="no-bookings-message">
                      <EventNoteIcon className="no-bookings-icon" />
                      <p>Loading bookings...</p>
                    </div>
                  );
                }
                
                const currentMonth = currentDate.getMonth();
                const currentYear = currentDate.getFullYear();
                
                // Filter bookings by trekDate month/year, day (if selected), status filter, and search
                const filteredBookings = allBookings
                  .filter(booking => {
                    if (!booking.trekDate) return false;
                    
                    const trekDate = booking.trekDate instanceof Timestamp 
                      ? booking.trekDate.toDate() 
                      : new Date(booking.trekDate);
                    
                    const matchesMonth = trekDate.getMonth() === currentMonth;
                    const matchesYear = trekDate.getFullYear() === currentYear;
                    // If a day is selected, filter by that day; otherwise show all days
                    const matchesDay = selectedDay === null || trekDate.getDate() === selectedDay;
                    
                    // Apply status filter
                    const status = booking.status?.toLowerCase();
                    let matchesStatus = true;
                    if (selectedFilter !== 'all') {
                      if (selectedFilter === 'completed') {
                        matchesStatus = status === 'completed';
                      } else if (selectedFilter === 'approve') {
                        matchesStatus = status === 'approved';
                      } else if (selectedFilter === 'canceled') {
                        matchesStatus = status === 'cancelled' || status === 'rejected';
                      } else if (selectedFilter === 'pending') {
                        matchesStatus = status === 'pending';
                      }
                    } else {
                      // Show all statuses when 'all' is selected
                      matchesStatus = true;
                    }
                    
                    const searchTerm = searchQuery.trim().toLowerCase();
                    const affiliation = (booking.affiliation || '').toLowerCase();
                    const matchesSearch = searchTerm === '' || affiliation.includes(searchTerm);
                    
                    return matchesMonth && matchesYear && matchesDay && matchesStatus && matchesSearch;
                  })
                  .sort((a, b) => {
                    const dateA = a.trekDate instanceof Timestamp ? a.trekDate.toDate() : new Date(a.trekDate);
                    const dateB = b.trekDate instanceof Timestamp ? b.trekDate.toDate() : new Date(b.trekDate);
                    return dateA.getDate() - dateB.getDate();
                  });
                
                if (filteredBookings.length === 0) {
                  let message = 'No scheduled booking';
                  if (selectedDay !== null) {
                    message = `No scheduled booking for ${selectedDay} ${currentDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}`;
                  } else if (selectedFilter !== 'all') {
                    const filterLabel = selectedFilter === 'completed' ? 'completed' :
                                      selectedFilter === 'approve' ? 'approved' :
                                      selectedFilter === 'canceled' ? 'cancelled' :
                                      selectedFilter === 'pending' ? 'pending' : '';
                    message = `No ${filterLabel} bookings for this month`;
                  } else {
                    message = 'No scheduled booking for this month';
                  }
                  
                  return (
                    <div className="no-bookings-message">
                      <EventNoteIcon className="no-bookings-icon" />
                      <p>{message}</p>
                    </div>
                  );
                }
                
                return filteredBookings.map(booking => {
                  const trekDate = booking.trekDate instanceof Timestamp 
                    ? booking.trekDate.toDate() 
                    : new Date(booking.trekDate);
                  const day = trekDate.getDate();
                  const month = trekDate.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
                  
                  // Get user data
                  const user = booking.userId ? usersMap.get(booking.userId) : null;
                  const trekkerName = user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User';
                  
                  // Map status
                  const status = booking.status?.toLowerCase();
                  let statusDisplay = 'Pending';
                  if (status === 'approved') {
                    statusDisplay = 'Approved';
                  } else if (status === 'completed') {
                    statusDisplay = 'Completed';
                  } else if (status === 'cancelled' || status === 'rejected') {
                    statusDisplay = 'Cancelled';
                  }
                  
                  return (
                    <div key={booking.id} className="upcoming-event-item">
                      <div className="upcoming-event-left">
                        <div className="upcoming-event-date">{day} {month}</div>
                      </div>
                      <div className="upcoming-event-content">
                        <div className="upcoming-event-name">{trekkerName}</div>
                        <div className="upcoming-event-affiliation">{booking.affiliation || 'N/A'}</div>
                        <div className="upcoming-event-trekkers">{booking.numberOfPorters || 1} Porter{booking.numberOfPorters !== 1 ? 's' : ''}</div>
                      </div>
                      <div className="upcoming-event-right">
                        <div className={`upcoming-event-status status-${statusDisplay.toLowerCase()}`} data-status={statusDisplay}>{statusDisplay}</div>
                      </div>
                    </div>
                  );
                });
              })()}
            </div>
          </div>
          </div>
        </div>
      ) : (
        <div className="calendar-view-container">
          {/* Calendar Header */}
          <div className="calendar-view-header">
            <div className="calendar-current-day">
              <h2>{formatCurrentDay(currentDate, selectedDay)}</h2>
            </div>
            <div className="calendar-month-navigation">
              <button className="calendar-nav-arrow" onClick={() => navigateMonth('prev')}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M15 18L9 12L15 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="calendar-month-year-display">
                {formatMonthYear(currentDate)}
              </span>
              <button className="calendar-nav-arrow" onClick={() => navigateMonth('next')}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <path d="M9 18L15 12L9 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          
          {/* Calendar Grid */}
          <div className="calendar-view-grid">
            <div className="calendar-weekdays-header">
              {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day, index) => {
                const currentDayOfWeek = getDayOfWeek(currentDate, selectedDay);
                // Calendar starts on Sunday (0), so no conversion needed
                const dayIndex = currentDayOfWeek;
                const isCurrentDay = index === dayIndex;
                return (
                  <div key={day} className={`calendar-weekday-header ${isCurrentDay ? 'highlighted' : ''}`}>
                    {day}
                  </div>
                );
              })}
            </div>
            <div className="calendar-days-grid">
              {(() => {
                const { daysInMonth, startingDayOfWeek } = getDaysInMonth(currentDate);
                const days = [];
                const year = currentDate.getFullYear();
                const month = currentDate.getMonth();
                
                // Get previous month's last day
                const prevMonth = new Date(year, month, 0);
                const prevMonthDays = prevMonth.getDate();
                
                // JavaScript's getDay() returns 0 for Sunday, 1 for Monday, etc.
                // Calendar starts on Sunday (0), so no adjustment needed
                const adjustedStart = startingDayOfWeek;
                
                // Days from previous month (fill in the gap before the first day of current month)
                for (let i = adjustedStart - 1; i >= 0; i--) {
                  const day = prevMonthDays - i;
                  days.push(
                    <div key={`prev-${day}`} className="calendar-day-cell other-month">
                      <div className="calendar-day-number">{day}</div>
                    </div>
                  );
                }
                
                // Days of the current month
                for (let day = 1; day <= daysInMonth; day++) {
                  const dayEvents = getEventsForDay(day);
                  const bookingCount = dayEvents.length;
                  const hasEvents = bookingCount > 0;
                  const isSelected = day === selectedDay;
                  
                  // Check calendar config for this day
                  const dateKey = formatDateKey(new Date(year, month, day));
                  const dateConfig = calendarConfigs[dateKey];
                  const isClosed = dateConfig?.isClosed || false;
                  const maxSlots = dateConfig?.maxSlots || calendarSettings?.defaultMaxSlots || 30;
                  
                  // Calculate availability percentage
                  let availabilityClass = '';
                  if (isClosed) {
                    availabilityClass = 'closed';
                  } else if (hasEvents) {
                    const participants = dayEvents.reduce((sum, booking) => sum + (booking.numberOfPorters || 1), 0);
                    const percentage = (participants / maxSlots) * 100;
                    if (percentage >= 80) {
                      availabilityClass = 'full';
                    } else if (percentage >= 30) {
                      availabilityClass = 'limited';
                    } else {
                      availabilityClass = 'available';
                    }
                  } else {
                    availabilityClass = 'available';
                  }
                  
                  days.push(
                    <div 
                      key={day} 
                      className={`calendar-day-cell ${isSelected ? 'selected' : ''} ${hasEvents ? 'has-events' : ''} ${availabilityClass}`}
                      onClick={() => {
                        // Toggle: if same day is clicked, deselect it
                        if (selectedDay === day) {
                          setSelectedDay(null);
                        } else {
                          setSelectedDay(day);
                        }
                      }}
                      title={isClosed ? `Closed: ${dateConfig?.reason || 'No bookings allowed'}` : 
                             dateConfig?.customNote ? dateConfig.customNote : 
                             hasEvents ? `${bookingCount} booking${bookingCount > 1 ? 's' : ''}` : 'Available'}
                    >
                      <div className="calendar-day-number">{day}</div>
                      {isClosed && (
                        <div className="closed-indicator" title={dateConfig?.reason || 'Closed'}>
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                            <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                          </svg>
                        </div>
                      )}
                      {hasEvents && !isClosed && (
                        <div className="calendar-day-booking-count">
                          <span className="booking-count-number">{bookingCount}</span>
                          <span className="booking-count-label">{bookingCount === 1 ? 'booking' : 'bookings'}</span>
                        </div>
                      )}
                    </div>
                  );
                }
                
                // Fill remaining cells with next month's days to complete the grid (always 7 columns)
                const totalCells = days.length;
                const cellsInGrid = Math.ceil(totalCells / 7) * 7;
                const remainingCells = cellsInGrid - totalCells;
                for (let i = 1; i <= remainingCells; i++) {
                  days.push(
                    <div key={`next-${i}`} className="calendar-day-cell other-month">
                      <div className="calendar-day-number">{i}</div>
                    </div>
                  );
                }
                
                return days;
              })()}
            </div>
          </div>
          
          {/* Slot Availability Indicator */}
          <div className="slot-availability-indicator">
            <div className="slot-indicator-item">
              <div className="slot-indicator-line available"></div>
              <span className="slot-indicator-label">Available</span>
            </div>
            <div className="slot-indicator-item">
              <div className="slot-indicator-line limited"></div>
              <span className="slot-indicator-label">Limited Slots</span>
            </div>
            <div className="slot-indicator-item">
              <div className="slot-indicator-line full"></div>
              <span className="slot-indicator-label">Full</span>
            </div>
          </div>
          
          {/* Bookings List for Selected Day */}
          {selectedDay !== null && (
            <div className="calendar-day-bookings-section">
              <div className="calendar-day-bookings-header">
                <h3 className="calendar-day-bookings-title">
                  Bookings for {formatCurrentDay(currentDate, selectedDay)}
                </h3>
              </div>
              <div className="calendar-day-bookings-list">
                {(() => {
                  if (loading) {
                    return (
                      <div className="no-bookings-message">
                        <EventNoteIcon className="no-bookings-icon" />
                        <p>Loading bookings...</p>
                      </div>
                    );
                  }
                  
                  const dayBookings = getEventsForDay(selectedDay);
                  
                  if (dayBookings.length === 0) {
                    return (
                      <div className="no-bookings-message">
                        <EventNoteIcon className="no-bookings-icon" />
                        <p>No bookings for this day</p>
                      </div>
                    );
                  }
                  
                  // Get calendar config for selected day
                  const selectedDateKey = formatDateKey(new Date(currentDate.getFullYear(), currentDate.getMonth(), selectedDay));
                  const selectedDateConfig = calendarConfigs[selectedDateKey];
                  
                  return (
                    <>
                      {selectedDateConfig && (selectedDateConfig.isClosed || selectedDateConfig.customNote || selectedDateConfig.reason) && (
                        <div className="calendar-day-info-banner" style={{
                          marginBottom: '16px',
                          padding: '12px 16px',
                          borderRadius: '8px',
                          backgroundColor: selectedDateConfig.isClosed ? '#fee' : '#e7f3ff',
                          border: `1px solid ${selectedDateConfig.isClosed ? '#fcc' : '#b3d9ff'}`,
                          color: selectedDateConfig.isClosed ? '#c33' : '#004085'
                        }}>
                          {selectedDateConfig.isClosed && (
                            <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>
                              ⚠️ This date is closed
                            </div>
                          )}
                          {selectedDateConfig.reason && (
                            <div style={{ fontSize: '14px', marginBottom: '4px' }}>
                              <strong>Reason:</strong> {selectedDateConfig.reason}
                            </div>
                          )}
                          {selectedDateConfig.customNote && (
                            <div style={{ fontSize: '14px' }}>
                              <strong>Note:</strong> {selectedDateConfig.customNote}
                            </div>
                          )}
                          {selectedDateConfig.maxSlots && (
                            <div style={{ fontSize: '14px', marginTop: '4px' }}>
                              <strong>Max Slots:</strong> {selectedDateConfig.maxSlots}
                            </div>
                          )}
                        </div>
                      )}
                      {dayBookings.map(booking => {
                        const trekDate = booking.trekDate instanceof Timestamp 
                          ? booking.trekDate.toDate() 
                          : new Date(booking.trekDate);
                        const day = trekDate.getDate();
                        const month = trekDate.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
                        
                        // Get user data
                        const user = booking.userId ? usersMap.get(booking.userId) : null;
                        const trekkerName = user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User';
                        
                        // Map status
                        const status = booking.status?.toLowerCase();
                        let statusDisplay = 'Pending';
                        if (status === 'approved') {
                          statusDisplay = 'Approved';
                        } else if (status === 'completed') {
                          statusDisplay = 'Completed';
                        } else if (status === 'cancelled' || status === 'rejected') {
                          statusDisplay = 'Cancelled';
                        }
                        
                        return (
                          <div key={booking.id} className="upcoming-event-item">
                            <div className="upcoming-event-left">
                              <div className="upcoming-event-date">{day} {month}</div>
                            </div>
                            <div className="upcoming-event-content">
                              <div className="upcoming-event-name">{trekkerName}</div>
                              <div className="upcoming-event-affiliation">{booking.affiliation || 'N/A'}</div>
                              <div className="upcoming-event-trekkers">{booking.numberOfPorters || 1} Porter{booking.numberOfPorters !== 1 ? 's' : ''}</div>
                            </div>
                            <div className="upcoming-event-right">
                              <div className={`upcoming-event-status status-${statusDisplay.toLowerCase()}`} data-status={statusDisplay}>{statusDisplay}</div>
                            </div>
                          </div>
                        );
                      })}
                    </>
                  );
                })()}
              </div>
            </div>
          )}
        </div>
      )}

    </div>
  );
}

export default ManageSchedule;
