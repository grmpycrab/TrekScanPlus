import React, { useState, useEffect } from 'react';
import { Card, CardContent, Box, Typography, LinearProgress } from '@mui/material';
import { Hiking } from '@mui/icons-material';
import { getAllBookings, formatBookingDate, subscribeToBookings } from '../../services/bookingService';
import { getUserById } from '../../services/userService';
import { getCurrentUser, onAuthStateChange } from '../../services/firebaseAuthService';
import { Timestamp } from 'firebase/firestore';
import '../style/Dashboard.css';
import '../style/shared.css';

function Dashboard({ onNavigate }) {
  const [trekActivityData, setTrekActivityData] = useState({ days: [], values: [] });
  const [trekActivityStats, setTrekActivityStats] = useState({
    peakActivity: { value: 0, date: '' },
    averageDaily: 0,
    capacityUsed: 0
  });
  
  // Generate trek activity data from approved bookings over the past 30 days
  const generateTrekActivity = React.useCallback((approvedBookings) => {
    const days = [];
    const values = [];
    
    // Get date range: past 30 days
    const endDate = new Date();
    endDate.setHours(23, 59, 59, 999);
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 29); // 30 days including today
    startDate.setHours(0, 0, 0, 0);
    
    const startDateStr = `${startDate.getFullYear()}-${String(startDate.getMonth() + 1).padStart(2, '0')}-${String(startDate.getDate()).padStart(2, '0')}`;
    const endDateStr = `${endDate.getFullYear()}-${String(endDate.getMonth() + 1).padStart(2, '0')}-${String(endDate.getDate()).padStart(2, '0')}`;
    console.log('Dashboard: Date range for chart:', { startDate: startDateStr, endDate: endDateStr, totalBookings: approvedBookings.length });
    
    // Group approved bookings by trekDate
    const bookingsByDate = {};
    let bookingsInRange = 0;
    let bookingsOutOfRange = 0;
    
    approvedBookings.forEach(booking => {
      if (!booking.trekDate) return;
      
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      
      const trekDateStr = `${trekDate.getFullYear()}-${String(trekDate.getMonth() + 1).padStart(2, '0')}-${String(trekDate.getDate()).padStart(2, '0')}`;
      
      // Only include bookings within the past 30 days
      if (trekDate >= startDate && trekDate <= endDate) {
        bookingsInRange++;
        const dateKey = trekDate.toDateString();
        if (!bookingsByDate[dateKey]) {
          bookingsByDate[dateKey] = 0;
        }
        bookingsByDate[dateKey] += 1; // Count each booking as 1 trekker
      } else {
        bookingsOutOfRange++;
        if (bookingsOutOfRange <= 3) {
          console.log(`Dashboard: Booking out of range - TrekDate: ${trekDateStr}, Status: ${booking.status}`);
        }
      }
    });
    
    console.log('Dashboard: Bookings in range:', bookingsInRange, 'Out of range:', bookingsOutOfRange);
    
    // Generate data for each day in the range
    for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
      const label = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
      days.push(label);
      
      const dateKey = d.toDateString();
      const count = bookingsByDate[dateKey] || 0;
      values.push(count);
    }
    
    return { days, values };
  }, []);
  
  // Calculate accurate total of active trekkers from the chart data
  const totalActiveTrekkers = trekActivityData.values.length > 0 
    ? trekActivityData.values.reduce((sum, value) => sum + value, 0) 
    : 0;

  // Chart dimensions
  const width = 900; // responsive via viewBox
  const height = 340;
  const padding = { top: 30, right: 24, bottom: 40, left: 44 };
  const innerW = width - padding.left - padding.right;
  const innerH = height - padding.top - padding.bottom;
  // Calculate maxY dynamically based on the data, with a minimum of 40
  const maxY = trekActivityData.values.length > 0 
    ? Math.max(40, Math.max(...trekActivityData.values, 0) + 5) 
    : 40;
  const capacity = 30;

  const xAt = (i) => padding.left + (i * innerW) / (Math.max(trekActivityData.values.length - 1, 1));
  const yAt = (v) => padding.top + innerH - (v / maxY) * innerH;

  // Smooth line using Catmull-Rom to cubic Bezier conversion
  const toPath = (pts) => {
    if (pts.length < 2) return '';
    const d = [];
    d.push(`M ${pts[0].x} ${pts[0].y}`);
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[i - 1] || pts[i];
      const p1 = pts[i];
      const p2 = pts[i + 1];
      const p3 = pts[i + 2] || p2;
      const tension = 0.2;
      const c1x = p1.x + (p2.x - p0.x) * tension;
      const c1y = p1.y + (p2.y - p0.y) * tension;
      const c2x = p2.x - (p3.x - p1.x) * tension;
      const c2y = p2.y - (p3.y - p1.y) * tension;
      d.push(`C ${c1x} ${c1y}, ${c2x} ${c2y}, ${p2.x} ${p2.y}`);
    }
    return d.join(' ');
  };

  const points = trekActivityData.values.map((v, i) => ({ x: xAt(i), y: yAt(v), v, i }));
  const pathD = toPath(points);
  const capacityY = yAt(capacity);

  const [hover, setHover] = React.useState(null);
  const [activeTab, setActiveTab] = React.useState('upcoming'); // 'upcoming' or 'recent'
  const [trekkerSearch, setTrekkerSearch] = React.useState('');
  const [showAllTrekkersModal, setShowAllTrekkersModal] = React.useState(false);
  const [upcomingClimbs, setUpcomingClimbs] = useState([]);
  const [recentApprovals, setRecentApprovals] = useState([]);
  const [todaysTrekkers, setTodaysTrekkers] = useState([]);
  const [stats, setStats] = useState({
    activeClimbs: 0,
    approvedCount: 0,
    pendingCount: 0,
    monthlyBookings: 0
  });
  const [loading, setLoading] = useState(true);

  // Fetch upcoming climbs and recent approvals
  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const currentUser = getCurrentUser();
      if (!currentUser) {
        setLoading(false);
        return;
      }

      // Get all bookings
      const allBookings = await getAllBookings();
      console.log('Dashboard: Total bookings fetched:', allBookings.length);
      
      // Filter bookings for trek activity chart (include all bookings with trekDate to show all activity)
      const approvedBookings = allBookings.filter(booking => {
        return booking.trekDate; // Include all bookings with a trekDate regardless of status
      });
      console.log('Dashboard: Bookings with trekDate:', approvedBookings.length);
      
      // Log status breakdown
      const statusBreakdown = {};
      approvedBookings.forEach(b => {
        const status = b.status?.toLowerCase() || 'unknown';
        statusBreakdown[status] = (statusBreakdown[status] || 0) + 1;
      });
      console.log('Dashboard: Status breakdown:', statusBreakdown);
      
      // Log some sample booking dates
      if (approvedBookings.length > 0) {
        const sampleDates = approvedBookings.slice(0, 5).map(b => {
          const trekDate = b.trekDate instanceof Timestamp 
            ? b.trekDate.toDate() 
            : new Date(b.trekDate);
          return trekDate.toISOString().split('T')[0];
        });
        console.log('Dashboard: Sample trek dates:', sampleDates);
      }
      
      // Generate trek activity data from approved bookings
      const activityData = generateTrekActivity(approvedBookings);
      console.log('Dashboard: Activity data generated:', {
        days: activityData.days.length,
        totalValues: activityData.values.reduce((a, b) => a + b, 0),
        values: activityData.values
      });
      setTrekActivityData(activityData);
      
      // Calculate stats for summary cards
      if (activityData.values.length > 0) {
        // Find peak activity
        const maxValue = Math.max(...activityData.values);
        const maxIndex = activityData.values.indexOf(maxValue);
        const peakDate = activityData.days[maxIndex];
        
        // Calculate average daily
        const totalTrekkers = activityData.values.reduce((sum, val) => sum + val, 0);
        const averageDaily = totalTrekkers / activityData.values.length;
        
        // Calculate capacity used percentage (assuming max capacity of 30 per day)
        const daysWithActivity = activityData.values.filter(v => v > 0).length;
        const totalCapacity = activityData.values.length * 30;
        const usedCapacity = activityData.values.reduce((sum, val) => sum + Math.min(val, 30), 0);
        const capacityUsed = totalCapacity > 0 ? Math.round((usedCapacity / totalCapacity) * 100) : 0;
        
        setTrekActivityStats({
          peakActivity: { value: maxValue, date: peakDate },
          averageDaily: averageDaily.toFixed(1),
          capacityUsed
        });
      }
      
      // Get today's date at midnight for comparison
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayTimestamp = Timestamp.fromDate(today);
      
      // Get date 7 days from now
      const sevenDaysFromNow = new Date();
      sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
      sevenDaysFromNow.setHours(23, 59, 59, 999);
      const sevenDaysTimestamp = Timestamp.fromDate(sevenDaysFromNow);

      // Filter approved bookings with upcoming dates (next 7 days)
      const upcomingBookings = allBookings
        .filter(booking => {
          const status = booking.status?.toLowerCase();
          const trekDate = booking.trekDate;
          if (!trekDate) return false;
          
          const trekDateTimestamp = trekDate instanceof Timestamp 
            ? trekDate 
            : Timestamp.fromDate(new Date(trekDate));
          
          return status === 'approved' && 
                 trekDateTimestamp >= todayTimestamp && 
                 trekDateTimestamp <= sevenDaysTimestamp;
        })
        .sort((a, b) => {
          const dateA = a.trekDate instanceof Timestamp 
            ? a.trekDate.toMillis() 
            : new Date(a.trekDate).getTime();
          const dateB = b.trekDate instanceof Timestamp 
            ? b.trekDate.toMillis() 
            : new Date(b.trekDate).getTime();
          return dateA - dateB;
        })
        .slice(0, 7); // Limit to 7 upcoming climbs

      // Fetch user data for upcoming climbs
      const upcomingWithUsers = await Promise.all(
        upcomingBookings.map(async (booking) => {
          const user = booking.userId ? await getUserById(booking.userId) : null;
          return {
            date: formatBookingDate(booking.trekDate, 'short'),
            name: user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User',
            status: booking.status?.toLowerCase() || 'pending',
            bookingId: booking.id
          };
        })
      );
      setUpcomingClimbs(upcomingWithUsers);

      // Get recent approvals (approved in the last 7 days, sorted by approval date)
      const recentApprovedBookings = allBookings
        .filter(booking => {
          const status = booking.status?.toLowerCase();
          return status === 'approved';
        })
        .sort((a, b) => {
          const dateA = a.updatedAt instanceof Timestamp 
            ? a.updatedAt.toMillis() 
            : (a.createdAt instanceof Timestamp ? a.createdAt.toMillis() : 0);
          const dateB = b.updatedAt instanceof Timestamp 
            ? b.updatedAt.toMillis() 
            : (b.createdAt instanceof Timestamp ? b.createdAt.toMillis() : 0);
          return dateB - dateA; // Most recent first
        })
        .slice(0, 4); // Limit to 4 recent approvals

      
      // Fetch user data for recent approvals
      const recentWithUsers = await Promise.all(
        recentApprovedBookings.map(async (booking) => {
          const user = booking.userId ? await getUserById(booking.userId) : null;
          return {
            date: formatBookingDate(booking.updatedAt || booking.createdAt, 'short'),
            name: user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User',
            status: 'approved',
            bookingId: booking.id
          };
        })
      );
      setRecentApprovals(recentWithUsers);

      // Get today's trekkers (approved bookings with trekDate = today)
      const todayBookings = allBookings.filter(booking => {
        const status = booking.status?.toLowerCase();
        const trekDate = booking.trekDate;
        if (!trekDate || status !== 'approved') return false;
        
        const trekDateTimestamp = trekDate instanceof Timestamp 
          ? trekDate 
          : Timestamp.fromDate(new Date(trekDate));
        
        const trekDateOnly = new Date(trekDateTimestamp.toDate());
        trekDateOnly.setHours(0, 0, 0, 0);
        
        return trekDateOnly.getTime() === today.getTime();
      });

      // Fetch user data for today's trekkers
      const todaysWithUsers = await Promise.all(
        todayBookings.map(async (booking, index) => {
          const user = booking.userId ? await getUserById(booking.userId) : null;
          return {
            id: booking.id,
            name: user ? `${user.firstName} ${user.lastName}`.trim() : 'Unknown User',
            time: '6:00 AM', // Default time, could be enhanced with actual time if stored
            status: 'confirmed',
            number: index + 1
          };
        })
      );
      setTodaysTrekkers(todaysWithUsers);

      // Calculate stats
      const approvedCount = allBookings.filter(b => b.status?.toLowerCase() === 'approved').length;
      const pendingCount = allBookings.filter(b => b.status?.toLowerCase() === 'pending').length;
      // Calculate active climbs - number of climbs scheduled for TODAY only
      const activeClimbs = allBookings
        .filter(b => {
          const status = b.status?.toLowerCase();
          const trekDate = b.trekDate;
          if (!trekDate) return false;
          
          // Only count approved bookings as active climbs
          if (status !== 'approved') return false;
          
          const trekDateTimestamp = trekDate instanceof Timestamp 
            ? trekDate 
            : Timestamp.fromDate(new Date(trekDate));
          const trekDateOnly = new Date(trekDateTimestamp.toDate());
          trekDateOnly.setHours(0, 0, 0, 0);
          
          // Count only climbs scheduled for TODAY (not future dates)
          return trekDateOnly.getTime() === today.getTime();
        })
        .reduce((total, booking) => {
          // Count number of trekkers: 1 (the booking user) + numberOfPorters (if porters are considered trekkers)
          // For now, counting each booking as 1 trekker (the person who booked)
          // If numberOfPorters represents additional trekkers, add: 1 + (booking.numberOfPorters || 0)
          return total + 1;
        }, 0);

      // Monthly bookings (current month)
      const currentMonth = new Date().getMonth();
      const currentYear = new Date().getFullYear();
      const monthlyBookings = allBookings.filter(b => {
        const createdAt = b.createdAt instanceof Timestamp 
          ? b.createdAt.toDate() 
          : new Date(b.createdAt);
        return createdAt.getMonth() === currentMonth && 
               createdAt.getFullYear() === currentYear;
      }).length;

      setStats({
        activeClimbs,
        approvedCount,
        pendingCount,
        monthlyBookings
      });

      setLoading(false);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      setLoading(false);
    }
  };

  // Fetch data on mount and when auth state changes
  useEffect(() => {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      setLoading(false);
      return;
    }

    // Set up real-time subscription for bookings to detect cancellations
    let unsubscribeBookings = null;
    if (currentUser) {
      unsubscribeBookings = subscribeToBookings(() => {
        // Refresh dashboard data when bookings change (including cancellations)
        fetchDashboardData();
      });
    }

    const unsubscribe = onAuthStateChange((user) => {
      if (user) {
        fetchDashboardData();
        // Set up subscription when user is authenticated
        if (!unsubscribeBookings) {
          unsubscribeBookings = subscribeToBookings(() => {
            fetchDashboardData();
          });
        }
      } else {
        // Clean up subscription when user logs out
        if (unsubscribeBookings) {
          unsubscribeBookings();
          unsubscribeBookings = null;
        }
        setUpcomingClimbs([]);
        setRecentApprovals([]);
        setTodaysTrekkers([]);
        setStats({
          activeClimbs: 0,
          approvedCount: 0,
          pendingCount: 0,
          monthlyBookings: 0
        });
        setLoading(false);
      }
    });

    if (currentUser) {
      fetchDashboardData();
    }

    return () => {
      unsubscribe();
      if (unsubscribeBookings) {
        unsubscribeBookings();
      }
    };
  }, []);

  const StatsCard = ({ title, value, subtitle, progress }) => (
    <Card elevation={2} sx={{ borderRadius: 2 }}>
      <CardContent>
        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
          {title}
        </Typography>
        <Typography variant="h3" component="div">
          {value}
        </Typography>
        {subtitle && (
          <Typography variant="body2" sx={{ mt: 1, color: progress ? 'text.secondary' : 'success.main' }}>
            {subtitle}
          </Typography>
        )}
        {typeof progress === 'number' && (
          <Box sx={{ mt: 2 }}>
            <LinearProgress
              variant="determinate"
              value={progress}
              sx={{
                height: 8,
                borderRadius: 9999,
                backgroundColor: '#edf2f7',
                '& .MuiLinearProgress-bar': {
                  backgroundColor: '#3a451e'
                }
              }}
            />
          </Box>
        )}
      </CardContent>
    </Card>
  );

  return (
    <div>
        {/* Stats Cards Section */}
        <div className="dashboard-stats-cards" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '24px' }}>
          {/* Monthly Bookings Card */}
          <div className="metric-card">
            <div className="metric-card-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M17 21V19C17 17.9391 16.5786 16.9217 15.8284 16.1716C15.0783 15.4214 14.0609 15 13 15H5C3.93913 15 2.92172 15.4214 2.17157 16.1716C1.42143 16.9217 1 17.9391 1 19V21" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M9 11C11.2091 11 13 9.20914 13 7C13 4.79086 11.2091 3 9 3C6.79086 3 5 4.79086 5 7C5 9.20914 6.79086 11 9 11Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M23 21V19C22.9993 18.1137 22.7044 17.2528 22.1614 16.5523C21.6184 15.8519 20.8581 15.3516 20 15.13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M16 3.13C16.8604 3.35031 17.623 3.85071 18.1676 4.55232C18.7122 5.25392 19.0078 6.11683 19.0078 7.005C19.0078 7.89318 18.7122 8.75608 18.1676 9.45769C17.623 10.1593 16.8604 10.6597 16 10.88" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value">{loading ? '...' : stats.monthlyBookings.toLocaleString()}</div>
              <div className="metric-card-label">Monthly Bookings</div>
            </div>
          </div>
          
          {/* Approved Card */}
          <div className="metric-card">
            <div className="metric-card-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M9 11L12 14L22 4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M21 12V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value">{loading ? '...' : stats.approvedCount.toLocaleString()}</div>
              <div className="metric-card-label">Approved</div>
            </div>
          </div>
          
          {/* Pending Card */}
          <div className="metric-card">
            <div className="metric-card-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
                <path d="M15 9L9 15M9 9L15 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              </svg>
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value">{loading ? '...' : stats.pendingCount.toLocaleString()}</div>
              <div className="metric-card-label">Pending</div>
            </div>
          </div>
          
          {/* Active Climbs Card */}
          <div className="metric-card">
            <div className="metric-card-icon">
              <Hiking sx={{ fontSize: 24 }} />
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value">{loading ? '...' : stats.activeClimbs.toLocaleString()}</div>
              <div className="metric-card-label">Active Climbs</div>
            </div>
          </div>
        </div>
        
        {/* Main dashboard content - two column layout */}
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', lg: '2fr 1fr' }, gap: 3, mt: 3 }}>
          {/* Left: Trek Activity Chart */}
          <Card elevation={2} className="trek-activity-card" sx={{ borderRadius: 2 }}>
            <div className="trek-activity-gradient-bar"></div>
            <CardContent>
              <div className="trek-activity-header">
                <div className="trek-activity-title-section">
                  <div className="trek-activity-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M3 12L7 8L12 12L17 7L21 11" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M3 20L7 16L12 20L17 15L21 19" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </div>
                  <div className="trek-activity-title-content">
                    <Typography variant="h6" component="h2" className="trek-activity-title">
                      Trekk Activity
                    </Typography>
                    <Typography variant="body2" className="trek-activity-subtitle">
                      Number of Trekkers over the past 30 days.
                    </Typography>
                  </div>
                </div>
                <span className="percent-badge">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M3 12L7 8L12 12L17 7L21 11" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                  +12%
                </span>
              </div>
              
              <div className="trek-activity-total">
                <Typography variant="h2" component="div" className="trek-activity-number">
                  {loading ? '...' : totalActiveTrekkers}
                </Typography>
                <Typography variant="body2" className="trek-activity-total-label">
                  total treks
                </Typography>
              </div>
              
              <div className="trek-chart">
                <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Trek Activity Line Chart">
                  <defs>
                    <clipPath id="clip-over">
                      <rect x="0" y="0" width={width} height={capacityY} />
                    </clipPath>
                  </defs>
                  
                  {/* Background */}
                  <rect x="0" y="0" width={width} height={height} fill="#f9fafb" rx="8" />

                  {/* Grid lines */}
                  {Array.from({ length: 5 }, (_, i) => {
                    const y = padding.top + (innerH / 4) * i;
                    const value = maxY - (maxY / 4) * i;
                    return (
                      <g key={`grid-${i}`}> 
                        <line x1={padding.left} x2={width - padding.right} y1={y} y2={y} stroke="#eeeeee" strokeWidth="1" />
                        <text x={padding.left - 8} y={y + 4} textAnchor="end" className="axis-text">{Math.round(value)}</text>
                      </g>
                    );
                  })}
                  
                  {/* Vertical grid lines for dates */}
                  {trekActivityData.days.map((d, i) => (i % 2 === 0 ? (
                    <line key={`vgrid-${i}`} x1={xAt(i)} x2={xAt(i)} y1={padding.top} y2={height - padding.bottom} stroke="#eeeeee" strokeWidth="1" />
                  ) : null))}

                  {/* X axis labels every 2 days to match the image */}
                  {trekActivityData.days.map((d, i) => (i % 2 === 0 ? (
                    <text key={`x-${i}`} x={xAt(i)} y={height - 8} textAnchor="middle" className="axis-text">{d}</text>
                  ) : null))}

                  {/* Capacity line */}
                  <line x1={padding.left} x2={width - padding.right} y1={capacityY} y2={capacityY} stroke="#ff9800" strokeDasharray="4 4" strokeWidth="2" />
                  <text x={width - padding.right - 4} y={capacityY - 4} textAnchor="end" className="capacity-label">Maxi</text>

                  {/* Area fill */}
                  {trekActivityData.values.length > 0 && (
                    <path d={`${pathD} L ${xAt(trekActivityData.values.length - 1)} ${height - padding.bottom} L ${xAt(0)} ${height - padding.bottom} Z`} fill="#e8f5e9" />
                  )}
                  
                  {/* Green line */}
                  {trekActivityData.values.length > 0 && (
                    <path d={pathD} fill="none" stroke="#30622f" strokeWidth="2.5" />
                  )}
                  
                  {/* Data points */}
                  {trekActivityData.values.length > 0 && points.map(p => (
                    <circle
                      key={`pt-${p.i}`}
                      cx={p.x}
                      cy={p.y}
                      r={4}
                      fill="#30622f"
                      stroke="#ffffff"
                      strokeWidth="2"
                      onMouseEnter={(e) => setHover({ x: p.x, y: p.y, v: p.v, label: trekActivityData.days[p.i], isOverCapacity: p.v > capacity })}
                      onMouseLeave={() => setHover(null)}
                    />
                  ))}

                  {/* Axes */}
                  <line x1={padding.left} x2={padding.left} y1={padding.top} y2={height - padding.bottom} stroke="#e5e7eb" strokeWidth="1" />
                  <line x1={padding.left} x2={width - padding.right} y1={height - padding.bottom} y2={height - padding.bottom} stroke="#e5e7eb" strokeWidth="1" />
                </svg>

                {hover && (
                  <div
                    className="trek-tooltip"
                    style={{ left: hover.x, top: hover.y }}
                  >
                    <div className="trek-tooltip-date">{hover.label}</div>
                    <div className="trek-tooltip-value">{hover.v} {hover.v === 1 ? 'trekker' : 'trekkers'}</div>
                    {hover.isOverCapacity && (
                      <div className="trek-tooltip-warning">• Above capacity</div>
                    )}
                  </div>
                )}
              </div>
              
              <div className="trek-activity-summary-cards">
                <div className="summary-card peak-activity">
                  <div className="summary-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M3 20L12 4L21 20H3Z" fill="currentColor"/>
                    </svg>
                  </div>
                  <div className="summary-card-content">
                    <div className="summary-card-title">Peak Activity</div>
                    <div className="summary-card-value">{loading ? '...' : trekActivityStats.peakActivity.value}</div>
                    <div className="summary-card-date">{loading ? '...' : trekActivityStats.peakActivity.date || 'N/A'}</div>
                  </div>
                </div>
                
                <div className="summary-card average-daily">
                  <div className="summary-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M17 21V19C17 17.9391 16.5786 16.9217 15.8284 16.1716C15.0783 15.4214 14.0609 15 13 15H5C3.93913 15 2.92172 15.4214 2.17157 16.1716C1.42143 16.9217 1 17.9391 1 19V21" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M9 11C11.2091 11 13 9.20914 13 7C13 4.79086 11.2091 3 9 3C6.79086 3 5 4.79086 5 7C5 9.20914 6.79086 11 9 11Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M23 21V19C22.9993 18.1137 22.7044 17.2528 22.1614 16.5523C21.6184 15.8519 20.8581 15.3516 20 15.13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M16 3.13C16.8604 3.35031 17.623 3.85071 18.1676 4.55232C18.7122 5.25392 19.0078 6.11683 19.0078 7.005C19.0078 7.89318 18.7122 8.75608 18.1676 9.45769C17.623 10.1593 16.8604 10.6597 16 10.88" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </div>
                  <div className="summary-card-content">
                    <div className="summary-card-title">Average Daily</div>
                    <div className="summary-card-value">{loading ? '...' : trekActivityStats.averageDaily}</div>
                    <div className="summary-card-subtitle">trekkers per day</div>
                  </div>
                </div>
                
                <div className="summary-card capacity-used">
                  <div className="summary-card-icon">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
                      <path d="M3 9H21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                      <path d="M9 3V21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                    </svg>
                  </div>
                  <div className="summary-card-content">
                    <div className="summary-card-title">Capacity Used</div>
                    <div className="summary-card-value">{loading ? '...' : `${trekActivityStats.capacityUsed}%`}</div>
                    <div className="summary-card-subtitle">of maximum capacity</div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Right: Today's Trekkers */}
          <Card elevation={2} className="todays-trekkers-card" sx={{ borderRadius: 2, overflow: 'hidden' }}>
            <div className="trekkers-header">
              <div className="trekkers-header-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M17 21V19C17 17.9391 16.5786 16.9217 15.8284 16.1716C15.0783 15.4214 14.0609 15 13 15H5C3.93913 15 2.92172 15.4214 2.17157 16.1716C1.42143 16.9217 1 17.9391 1 19V21" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M9 11C11.2091 11 13 9.20914 13 7C13 4.79086 11.2091 3 9 3C6.79086 3 5 4.79086 5 7C5 9.20914 6.79086 11 9 11Z" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M23 21V19C22.9993 18.1137 22.7044 17.2528 22.1614 16.5523C21.6184 15.8519 20.8581 15.3516 20 15.13" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M16 3.13C16.8604 3.35031 17.623 3.85071 18.1676 4.55232C18.7122 5.25392 19.0078 6.11683 19.0078 7.005C19.0078 7.89318 18.7122 8.75608 18.1676 9.45769C17.623 10.1593 16.8604 10.6597 16 10.88" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div className="trekkers-header-content">
                <Typography variant="h6" component="h2" className="trekkers-header-title">
                  Today's Trekkers
                </Typography>
                <div className="trekkers-header-subtitle">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="3" y="4" width="18" height="18" rx="2" stroke="white" strokeWidth="2"/>
                    <path d="M16 2V6" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                    <path d="M8 2V6" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                    <path d="M3 10H21" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                  </svg>
                  <span>Trekkers scheduled for today</span>
                </div>
              </div>
            </div>
            
            <CardContent sx={{ padding: '16px !important' }}>
              <div className="trekkers-search">
                <input
                  type="text"
                  className="trekkers-search-input"
                  placeholder="Search trekkers..."
                  value={trekkerSearch}
                  onChange={(e) => setTrekkerSearch(e.target.value)}
                />
                <svg className="trekkers-search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M21 21L15 15M17 10C17 13.866 13.866 17 10 17C6.13401 17 3 13.866 3 10C3 6.13401 6.13401 3 10 3C13.866 3 17 6.13401 17 10Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              
              <div className="trekkers-list">
                {loading ? (
                  <div style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                    Loading trekkers...
                  </div>
                ) : todaysTrekkers.length === 0 ? (
                  <div style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                    No trekkers scheduled for today
                  </div>
                ) : (
                  todaysTrekkers
                    .filter(trekker => 
                      !trekkerSearch || 
                      trekker.name.toLowerCase().includes(trekkerSearch.toLowerCase())
                    )
                    .slice(0, 5)
                    .map((trekker) => (
                    <div key={trekker.id} className="trekker-item">
                      <div className="trekker-badge">{trekker.number}</div>
                      <div className="trekker-info">
                        <div className="trekker-name">{trekker.name}</div>
                      </div>
                    </div>
                  ))
                )}
              </div>
              
              {!loading && todaysTrekkers.length > 5 && (
                <button className="view-all-trekkers-btn" onClick={() => setShowAllTrekkersModal(true)}>
                  View All {todaysTrekkers.length - 5} More Trekkers
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M6 9L12 15L18 9" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
              )}
              
              <div className="trekkers-footer">
                <span className="trekkers-footer-label">Total Trekkers Today:</span>
                <span className="trekkers-footer-count">{loading ? '...' : todaysTrekkers.length}</span>
              </div>
            </CardContent>
          </Card>
        </Box>

        {/* Upcoming Climbs Card */}
        <Card elevation={2} className="upcoming-climbs-card" sx={{ borderRadius: 2, mt: 3 }}>
          <CardContent>
            <div className="upcoming-climbs-header">
              <div className="upcoming-climbs-title-section">
                <div className="upcoming-climbs-icon">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M3 20L12 4L21 20H3Z" fill="white"/>
                    <path d="M8 20L12 12L16 20H8Z" fill="white" opacity="0.8"/>
                  </svg>
                </div>
                <div className="upcoming-climbs-title-content">
                  <Typography variant="h6" component="h2" className="upcoming-climbs-title">
                    Upcoming Climbs
                  </Typography>
                  <Typography variant="body2" className="upcoming-climbs-subtitle">
                    Climbs scheduled for the next 7 days
                  </Typography>
                </div>
              </div>
              <button className="view-all-btn" onClick={() => onNavigate && onNavigate('climb')}>VIEW ALL</button>
            </div>
            
            <div className="climbs-tabs">
              <button 
                className={`tab-btn ${activeTab === 'upcoming' ? 'active' : ''}`}
                onClick={() => setActiveTab('upcoming')}
              >
                UPCOMING CLIMBS
              </button>
              <button 
                className={`tab-btn ${activeTab === 'recent' ? 'active' : ''}`}
                onClick={() => setActiveTab('recent')}
              >
                RECENT APPROVALS
              </button>
            </div>
            
            <div className="climbs-table">
              <div className="table-header">
                <div className="table-cell">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="3" y="4" width="18" height="18" rx="2" stroke="white" strokeWidth="2"/>
                    <path d="M16 2V6" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                    <path d="M8 2V6" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                    <path d="M3 10H21" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                  </svg>
                  Date
                </div>
                <div className="table-cell">Name</div>
                <div className="table-cell">Status</div>
              </div>
              {loading ? (
                <div style={{ padding: '40px', textAlign: 'center', color: '#666' }}>
                  Loading climbs...
                </div>
              ) : activeTab === 'upcoming' ? (
                upcomingClimbs.length === 0 ? (
                  <div style={{ padding: '40px', textAlign: 'center', color: '#666' }}>
                    No upcoming climbs in the next 7 days
                  </div>
                ) : (
                  upcomingClimbs.map((climb, index) => (
                    <div key={climb.bookingId || index} className="table-row">
                      <div className="table-cell">{climb.date}</div>
                      <div className="table-cell">{climb.name}</div>
                      <div className="table-cell">
                        <span className={`status-badge ${climb.status === 'approved' ? 'confirmed' : climb.status}`}>
                          {climb.status === 'approved' ? 'Confirmed' : 
                           climb.status === 'confirmed' ? 'Confirmed' : 
                           climb.status === 'cancelled' ? 'Cancelled' : 'Pending'}
                        </span>
                      </div>
                    </div>
                  ))
                )
              ) : (
                recentApprovals.length === 0 ? (
                  <div style={{ padding: '40px', textAlign: 'center', color: '#666' }}>
                    No recent approvals
                  </div>
                ) : (
                  recentApprovals.map((approval, index) => (
                    <div key={approval.bookingId || index} className="table-row">
                      <div className="table-cell">{approval.date}</div>
                      <div className="table-cell">{approval.name}</div>
                      <div className="table-cell">
                        <span className="status-badge approved">Approved</span>
                      </div>
                    </div>
                  ))
                )
              )}
            </div>
          </CardContent>
        </Card>

        {/* All Trekkers Modal */}
        {showAllTrekkersModal && (
          <div className="trekkers-modal-backdrop" onClick={() => setShowAllTrekkersModal(false)}>
            <div className="trekkers-modal" onClick={(e) => e.stopPropagation()}>
              <div className="trekkers-modal-header">
                <h2>All Trekkers Today</h2>
                <button 
                  className="trekkers-modal-close"
                  onClick={() => setShowAllTrekkersModal(false)}
                  aria-label="Close"
                >
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
              </div>
              
              <div className="trekkers-modal-content">
                <div className="trekkers-modal-search">
                  <input
                    type="text"
                    className="trekkers-modal-search-input"
                    placeholder="Search trekkers..."
                    value={trekkerSearch}
                    onChange={(e) => setTrekkerSearch(e.target.value)}
                  />
                  <svg className="trekkers-modal-search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M21 21L15 15M17 10C17 13.866 13.866 17 10 17C6.13401 17 3 13.866 3 10C3 6.13401 6.13401 3 10 3C13.866 3 17 6.13401 17 10Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </div>

                <div className="trekkers-modal-list">
                  {loading ? (
                    <div style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                      Loading trekkers...
                    </div>
                  ) : todaysTrekkers.length === 0 ? (
                    <div style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                      No trekkers scheduled for today
                    </div>
                  ) : (
                    todaysTrekkers
                      .filter(trekker => 
                        !trekkerSearch || 
                        trekker.name.toLowerCase().includes(trekkerSearch.toLowerCase())
                      )
                      .map((trekker) => (
                        <div key={trekker.id} className="trekker-modal-item">
                          <div className="trekker-badge">{trekker.number}</div>
                          <div className="trekker-info">
                            <div className="trekker-name">{trekker.name}</div>
                          </div>
                        </div>
                      ))
                  )}
                </div>
              </div>
              
              <div className="trekkers-modal-footer">
                <span className="trekkers-footer-label">Total Trekkers Today:</span>
                <span className="trekkers-footer-count">{loading ? '...' : todaysTrekkers.length}</span>
              </div>
            </div>
          </div>
        )}
      </div>
  );
}

export default Dashboard;
