import React, { useState, useMemo, useCallback, useEffect } from 'react';
import { Card, CardContent, Typography, Box } from '@mui/material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';
import dayjs from 'dayjs';
import { getAllBookings } from '../../services/bookingService';
import { getCurrentUser, onAuthStateChange } from '../../services/firebaseAuthService';
import { Timestamp } from 'firebase/firestore';
import * as XLSX from 'xlsx';
import jsPDF from 'jspdf';
import '../style/Reports.css';

function Reports() {
  const [timeFilter, setTimeFilter] = useState('monthly'); // 'daily', 'weekly', 'monthly', 'custom'
  const [customStartDate, setCustomStartDate] = useState(dayjs().subtract(30, 'day'));
  const [customEndDate, setCustomEndDate] = useState(dayjs());
  const [showCustomDatePicker, setShowCustomDatePicker] = useState(false);
  const [showExportMenu, setShowExportMenu] = useState(false);
  const [allBookings, setAllBookings] = useState([]);
  const [loading, setLoading] = useState(true);

  // Fetch bookings from Firebase
  useEffect(() => {
    const fetchBookings = async () => {
      try {
        setLoading(true);
        const currentUser = getCurrentUser();
        if (!currentUser) {
          setLoading(false);
          return;
        }

        const bookings = await getAllBookings();
        setAllBookings(bookings);
      } catch (error) {
        console.error('Error fetching bookings:', error);
        setAllBookings([]);
      } finally {
        setLoading(false);
      }
    };

    const unsubscribe = onAuthStateChange((user) => {
      if (user) {
        fetchBookings();
      } else {
        setAllBookings([]);
        setLoading(false);
      }
    });

    const currentUser = getCurrentUser();
    if (currentUser) {
      fetchBookings();
    }

    return () => unsubscribe();
  }, []);

  // Generate real data based on time filter and bookings
  const generateTrekkerActivity = useCallback(() => {
    const days = [];
    const values = [];
    let startDate, endDate, interval;

    switch (timeFilter) {
      case 'daily':
        // Last 7 days
        startDate = dayjs().subtract(6, 'day');
        endDate = dayjs();
        interval = 'day';
        break;
      case 'weekly':
        // Last 7 weeks
        startDate = dayjs().subtract(6, 'week');
        endDate = dayjs();
        interval = 'week';
        break;
      case 'monthly':
        // Last 12 months
        startDate = dayjs().subtract(11, 'month');
        endDate = dayjs();
        interval = 'month';
        break;
      case 'custom':
        startDate = customStartDate;
        endDate = customEndDate;
        interval = 'day';
        break;
      default:
        startDate = dayjs().subtract(11, 'month');
        endDate = dayjs();
        interval = 'month';
    }

    // Filter bookings within the date range (based on trekDate)
    const filteredBookings = allBookings.filter(booking => {
      if (!booking.trekDate) return false;
      
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      
      const bookingDate = dayjs(trekDate);
      return (bookingDate.isAfter(startDate.subtract(1, 'day')) || bookingDate.isSame(startDate, 'day')) 
        && (bookingDate.isBefore(endDate.add(1, 'day')) || bookingDate.isSame(endDate, 'day'));
    });

    // Group bookings by period based on interval
    const bookingsByPeriod = {};
    
    filteredBookings.forEach(booking => {
      if (!booking.trekDate) return;
      
      const trekDate = booking.trekDate instanceof Timestamp 
        ? booking.trekDate.toDate() 
        : new Date(booking.trekDate);
      
      let periodKey;
      if (interval === 'day') {
        periodKey = dayjs(trekDate).format('YYYY-MM-DD');
      } else if (interval === 'week') {
        const weekStart = dayjs(trekDate).startOf('week');
        periodKey = `${weekStart.year()}-W${weekStart.week()}`;
      } else {
        periodKey = dayjs(trekDate).format('YYYY-MM');
      }
      
      if (!bookingsByPeriod[periodKey]) {
        bookingsByPeriod[periodKey] = [];
      }
      bookingsByPeriod[periodKey].push(booking);
    });

    // Generate data points for each period
    let current = startDate;
    while (current.isBefore(endDate) || current.isSame(endDate, 'day')) {
      let periodKey;
      let label;
      
      if (interval === 'day') {
        periodKey = current.format('YYYY-MM-DD');
        label = current.format('MMM D');
      } else if (interval === 'week') {
        const weekStart = current.startOf('week');
        periodKey = `${weekStart.year()}-W${weekStart.week()}`;
        label = `Week ${current.week()}`;
      } else {
        periodKey = current.format('YYYY-MM');
        label = current.format('MMM YYYY');
      }
      
      days.push(label);
      
      // Count approved and completed trekkers for this period
      const periodBookings = bookingsByPeriod[periodKey] || [];
      const approvedCount = periodBookings.filter(b => {
        const status = b.status?.toLowerCase();
        return status === 'approved' || status === 'completed';
      }).length;
      values.push(approvedCount);
      
      current = current.add(1, interval);
    }

    return { days, values };
  }, [timeFilter, customStartDate, customEndDate, allBookings]);

  const { days, values } = generateTrekkerActivity();

  // Calculate metrics from real booking data
  const metrics = useMemo(() => {
    // Get date range for filtering
    let startDate, endDate;
    switch (timeFilter) {
      case 'daily':
        startDate = dayjs().subtract(6, 'day');
        endDate = dayjs();
        break;
      case 'weekly':
        startDate = dayjs().subtract(6, 'week');
        endDate = dayjs();
        break;
      case 'monthly':
        startDate = dayjs().subtract(11, 'month');
        endDate = dayjs();
        break;
      case 'custom':
        startDate = customStartDate;
        endDate = customEndDate;
        break;
      default:
        startDate = dayjs().subtract(11, 'month');
        endDate = dayjs();
    }

    // Filter bookings within date range (based on createdAt)
    const filteredBookings = allBookings.filter(booking => {
      if (!booking.createdAt) return false;
      const createdAt = booking.createdAt instanceof Timestamp 
        ? booking.createdAt.toDate() 
        : new Date(booking.createdAt);
      const bookingDate = dayjs(createdAt);
      return (bookingDate.isAfter(startDate.subtract(1, 'day')) || bookingDate.isSame(startDate, 'day'))
        && (bookingDate.isBefore(endDate.add(1, 'day')) || bookingDate.isSame(endDate, 'day'));
    });

    // Calculate metrics
    const totalBookings = filteredBookings.length;
    const approvedBookings = filteredBookings.filter(b => {
      const status = b.status?.toLowerCase();
      return status === 'approved' || status === 'completed';
    });
    const cancelledBookings = filteredBookings.filter(b => b.status?.toLowerCase() === 'cancelled' || b.status?.toLowerCase() === 'rejected');
    
    // Count unique users (trekkers) - each user should only be counted once
    const uniqueUserIds = new Set(approvedBookings.map(b => b.userId).filter(id => id)); // Filter out null/undefined
    const totalTrekkers = uniqueUserIds.size;
    const totalCancellations = cancelledBookings.length;

    // Calculate daily trekkers (average or latest based on filter)
    const dailyTrekkers = timeFilter === 'daily' ? values[values.length - 1] || 0 : 
                         timeFilter === 'weekly' ? Math.round(totalTrekkers / 7) :
                         timeFilter === 'monthly' ? Math.round(totalTrekkers / 30) : 
                         values[values.length - 1] || 0;
    
    const dailyCapacity = 30;

    // Calculate average group size (assuming 1 trekker per booking for now)
    const avgGroupSize = totalBookings > 0 ? (totalTrekkers / totalBookings).toFixed(1) : '0';

    // Find peak activity
    const maxValue = values.length > 0 ? Math.max(...values, 0) : 0;
    const maxIndex = values.indexOf(maxValue);
    const peakLabel = maxIndex >= 0 && days[maxIndex] ? days[maxIndex] : 'N/A';

    // Calculate most popular day of week from actual bookings
    const dayCounts = {
      'Monday': 0,
      'Tuesday': 0,
      'Wednesday': 0,
      'Thursday': 0,
      'Friday': 0,
      'Saturday': 0,
      'Sunday': 0
    };

    approvedBookings.forEach(booking => {
      if (booking.trekDate) {
        const trekDate = booking.trekDate instanceof Timestamp 
          ? booking.trekDate.toDate() 
          : new Date(booking.trekDate);
        const dayName = dayjs(trekDate).format('dddd');
        if (dayCounts[dayName] !== undefined) {
          dayCounts[dayName]++;
        }
      }
    });

    const mostPopularDay = Object.entries(dayCounts).reduce((a, b) => 
      dayCounts[a[0]] > dayCounts[b[0]] ? a : b
    )[0] || 'N/A';

    // Calculate number of periods for averages
    let numberOfPeriods;
    if (timeFilter === 'daily') {
      numberOfPeriods = 7; // Last 7 days
    } else if (timeFilter === 'weekly') {
      numberOfPeriods = 7; // Last 7 weeks
    } else if (timeFilter === 'monthly') {
      numberOfPeriods = 12; // Last 12 months
    } else {
      // Custom range: calculate days between start and end
      numberOfPeriods = endDate.diff(startDate, 'day') + 1;
    }

    // Calculate averages
    const avgTrekkersNum = numberOfPeriods > 0 ? totalTrekkers / numberOfPeriods : 0;
    const avgTrekkers = avgTrekkersNum.toFixed(1);
    const avgBookings = numberOfPeriods > 0 ? (totalBookings / numberOfPeriods).toFixed(1) : '0';
    const avgCancellations = numberOfPeriods > 0 ? (totalCancellations / numberOfPeriods).toFixed(1) : '0';

    // Calculate total capacity based on time filter
    let totalCapacity;
    if (timeFilter === 'daily') {
      totalCapacity = dailyCapacity * 7; // 7 days
    } else if (timeFilter === 'weekly') {
      totalCapacity = dailyCapacity * 7 * 7; // 7 days per week * 7 weeks
    } else if (timeFilter === 'monthly') {
      // Average 30 days per month * 12 months
      totalCapacity = dailyCapacity * 30 * 12;
    } else {
      // Custom range: calculate days between start and end
      const daysInRange = endDate.diff(startDate, 'day') + 1;
      totalCapacity = dailyCapacity * daysInRange;
    }

    // Calculate average capacity used based on average trekkers
    const capacityUsed = avgTrekkersNum > 0 ? Math.round((avgTrekkersNum / dailyCapacity) * 100) : 0;

    // Calculate previous period metrics for comparison
    let prevStartDate, prevEndDate;
    if (timeFilter === 'daily') {
      // Previous 7 days before current period
      prevEndDate = startDate.subtract(1, 'day');
      prevStartDate = prevEndDate.subtract(6, 'day');
    } else if (timeFilter === 'weekly') {
      // Previous 7 weeks before current period
      prevEndDate = startDate.subtract(1, 'day');
      prevStartDate = prevEndDate.subtract(6, 'week');
    } else if (timeFilter === 'monthly') {
      // Previous 12 months before current period
      prevEndDate = startDate.subtract(1, 'day');
      prevStartDate = prevEndDate.subtract(11, 'month');
    } else {
      // Custom: previous period of same length
      const daysInRange = endDate.diff(startDate, 'day') + 1;
      prevEndDate = startDate.subtract(1, 'day');
      prevStartDate = prevEndDate.subtract(daysInRange - 1, 'day');
    }

    // Filter bookings for previous period
    const prevFilteredBookings = allBookings.filter(booking => {
      if (!booking.createdAt) return false;
      const createdAt = booking.createdAt instanceof Timestamp 
        ? booking.createdAt.toDate() 
        : new Date(booking.createdAt);
      const bookingDate = dayjs(createdAt);
      return (bookingDate.isAfter(prevStartDate.subtract(1, 'day')) || bookingDate.isSame(prevStartDate, 'day'))
        && (bookingDate.isBefore(prevEndDate.add(1, 'day')) || bookingDate.isSame(prevEndDate, 'day'));
    });

    const prevTotalBookings = prevFilteredBookings.length;
    const prevApprovedBookings = prevFilteredBookings.filter(b => {
      const status = b.status?.toLowerCase();
      return status === 'approved' || status === 'completed';
    });
    const prevCancelledBookings = prevFilteredBookings.filter(b => b.status?.toLowerCase() === 'cancelled' || b.status?.toLowerCase() === 'rejected');
    
    // Count unique users (trekkers) for previous period - each user should only be counted once
    const prevUniqueUserIds = new Set(prevApprovedBookings.map(b => b.userId).filter(id => id)); // Filter out null/undefined
    const prevTotalTrekkers = prevUniqueUserIds.size;
    const prevTotalCancellations = prevCancelledBookings.length;

    // Calculate previous period averages
    const prevAvgTrekkersNum = numberOfPeriods > 0 ? prevTotalTrekkers / numberOfPeriods : 0;
    const prevCapacityUsed = prevAvgTrekkersNum > 0 ? Math.round((prevAvgTrekkersNum / dailyCapacity) * 100) : 0;

    // Calculate percentage changes
    const calculatePercentageChange = (current, previous) => {
      if (previous === 0) {
        return current > 0 ? 100 : 0; // If previous was 0 and current > 0, it's 100% increase
      }
      return Math.round(((current - previous) / previous) * 100);
    };

    const trekkersChange = calculatePercentageChange(totalTrekkers, prevTotalTrekkers);
    const bookingsChange = calculatePercentageChange(totalBookings, prevTotalBookings);
    const cancellationsChange = calculatePercentageChange(totalCancellations, prevTotalCancellations);
    const capacityChange = calculatePercentageChange(capacityUsed, prevCapacityUsed);

    return {
      totalTrekkers,
      dailyTrekkers,
      totalBookings,
      totalCancellations,
      capacityUsed,
      avgGroupSize,
      peakValue: maxValue,
      peakLabel,
      mostPopularDay,
      dayCounts,
      avgTrekkers,
      avgBookings,
      avgCancellations,
      totalCapacity,
      trekkersChange,
      bookingsChange,
      cancellationsChange,
      capacityChange
    };
  }, [values, days, timeFilter, customStartDate, customEndDate, allBookings]);

  // Chart dimensions for Trekker Activity Trend
  const chartWidth = 900;
  const chartHeight = 340;
  const padding = { top: 30, right: 24, bottom: 40, left: 44 };
  const innerW = chartWidth - padding.left - padding.right;
  const innerH = chartHeight - padding.top - padding.bottom;
  // Calculate maxY dynamically based on data, with minimum of 10
  const maxY = values.length > 0 ? Math.max(40, Math.max(...values, 0) + 5) : 40;

  const xAt = (i) => padding.left + (i * innerW) / (values.length - 1 || 1);
  const yAt = (v) => padding.top + innerH - (v / maxY) * innerH;

  // Smooth line path
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

  const points = values.map((v, i) => ({ x: xAt(i), y: yAt(v), v, i }));
  const pathD = toPath(points);
  const [hover, setHover] = useState(null);
  const [barHover, setBarHover] = useState(null);

  // Booking vs Cancellation data from real bookings
  const bookingData = useMemo(() => {
    let startDate, endDate, interval;

    switch (timeFilter) {
      case 'daily':
        startDate = dayjs().subtract(6, 'day');
        endDate = dayjs();
        interval = 'day';
        break;
      case 'weekly':
        startDate = dayjs().subtract(6, 'week');
        endDate = dayjs();
        interval = 'week';
        break;
      case 'monthly':
        startDate = dayjs().subtract(11, 'month');
        endDate = dayjs();
        interval = 'month';
        break;
      case 'custom':
        startDate = customStartDate;
        endDate = customEndDate;
        interval = 'day';
        break;
      default:
        startDate = dayjs().subtract(11, 'month');
        endDate = dayjs();
        interval = 'month';
    }

    // Group bookings by period
    const bookingsByPeriod = {};
    const cancellationsByPeriod = {};

    allBookings.forEach(booking => {
      if (!booking.createdAt) return;
      
      const createdAt = booking.createdAt instanceof Timestamp 
        ? booking.createdAt.toDate() 
        : new Date(booking.createdAt);
      
      const bookingDate = dayjs(createdAt);
      if (!((bookingDate.isAfter(startDate.subtract(1, 'day')) || bookingDate.isSame(startDate, 'day'))
        && (bookingDate.isBefore(endDate.add(1, 'day')) || bookingDate.isSame(endDate, 'day')))) {
        return;
      }

      let periodKey;
      if (interval === 'day') {
        periodKey = bookingDate.format('YYYY-MM-DD');
      } else if (interval === 'week') {
        const weekStart = bookingDate.startOf('week');
        periodKey = `${weekStart.year()}-W${weekStart.week()}`;
      } else {
        periodKey = bookingDate.format('YYYY-MM');
      }

      if (!bookingsByPeriod[periodKey]) {
        bookingsByPeriod[periodKey] = 0;
        cancellationsByPeriod[periodKey] = 0;
      }

      bookingsByPeriod[periodKey]++;
      
      if (booking.status?.toLowerCase() === 'cancelled' || booking.status?.toLowerCase() === 'rejected') {
        cancellationsByPeriod[periodKey]++;
      }
    });

    // Map to same periods as days array
    const bookingValues = days.map((_, index) => {
      let periodKey;
      let current = startDate;
      let currentIndex = 0;
      
      while (currentIndex < index) {
        current = current.add(1, interval);
        currentIndex++;
      }
      
      if (interval === 'day') {
        periodKey = current.format('YYYY-MM-DD');
      } else if (interval === 'week') {
        const weekStart = current.startOf('week');
        periodKey = `${weekStart.year()}-W${weekStart.week()}`;
      } else {
        periodKey = current.format('YYYY-MM');
      }
      
      return bookingsByPeriod[periodKey] || 0;
    });

    const cancellationValues = days.map((_, index) => {
      let periodKey;
      let current = startDate;
      let currentIndex = 0;
      
      while (currentIndex < index) {
        current = current.add(1, interval);
        currentIndex++;
      }
      
      if (interval === 'day') {
        periodKey = current.format('YYYY-MM-DD');
      } else if (interval === 'week') {
        const weekStart = current.startOf('week');
        periodKey = `${weekStart.year()}-W${weekStart.week()}`;
      } else {
        periodKey = current.format('YYYY-MM');
      }
      
      return cancellationsByPeriod[periodKey] || 0;
    });

    return { bookingValues, cancellationValues };
  }, [timeFilter, customStartDate, customEndDate, allBookings, days]);

  // Bar chart dimensions and calculations - memoized for performance
  const barChartConfig = useMemo(() => {
    const barChartWidth = 900;
    const barChartHeight = 300;
    const barPadding = { top: 30, right: 24, bottom: 40, left: 44 };
    const barInnerW = barChartWidth - barPadding.left - barPadding.right;
    const barInnerH = barChartHeight - barPadding.top - barPadding.bottom;
    
    // Calculate max Y value with proper scaling
    const allValues = [...bookingData.bookingValues, ...bookingData.cancellationValues];
    const maxValue = Math.max(...allValues, 1);
    const barMaxY = maxValue > 0 ? Math.ceil(maxValue * 1.2) : 10;
    
    // Calculate bar positioning - works for any number of data points
    const numBars = values.length;
    const barGroupSpacing = numBars > 1 ? barInnerW / numBars : barInnerW;
    const barGroupWidth = Math.min(barGroupSpacing * 0.7, 40); // Max width per group, adaptive spacing
    
    const barXAt = (i) => {
      if (numBars === 1) {
        return barPadding.left + barInnerW / 2;
      }
      return barPadding.left + (i * barGroupSpacing) + (barGroupSpacing / 2);
    };
    
    const barYAt = (v) => {
      if (barMaxY === 0) return barPadding.top + barInnerH;
      return barPadding.top + barInnerH - (v / barMaxY) * barInnerH;
    };
    
    // Calculate individual bar width (two bars per group: booking + cancellation)
    const barWidth = Math.max(barGroupWidth * 0.35, 8); // Each bar is 35% of group width, min 8px
    const barGap = Math.max(barGroupWidth * 0.1, 2); // Gap between booking and cancellation bars
    
    return {
      barChartWidth,
      barChartHeight,
      barPadding,
      barInnerW,
      barInnerH,
      barMaxY,
      barXAt,
      barYAt,
      barWidth,
      barGap
    };
  }, [values, bookingData]);

  const {
    barChartWidth,
    barChartHeight,
    barPadding,
    barInnerW,
    barInnerH,
    barMaxY,
    barXAt,
    barYAt,
    barWidth,
    barGap
  } = barChartConfig;


  // Prepare export data
  const prepareExportData = useMemo(() => {
    const periodLabel = timeFilter === 'daily' ? 'Daily' : 
                        timeFilter === 'weekly' ? 'Weekly' : 
                        timeFilter === 'monthly' ? 'Monthly' : 
                        `Custom (${customStartDate.format('MMM D, YYYY')} - ${customEndDate.format('MMM D, YYYY')})`;
    
    // Summary metrics
    const summaryData = {
      period: periodLabel,
      totalTrekkers: metrics.totalTrekkers,
      totalBookings: metrics.totalBookings,
      totalCancellations: metrics.totalCancellations,
      capacityUsed: `${metrics.capacityUsed}%`,
      averageGroupSize: metrics.avgGroupSize,
      peakActivity: `${metrics.peakLabel} (${metrics.peakValue} trekkers)`,
      mostPopularDay: metrics.mostPopularDay
    };

    // Trekker activity data (for charts)
    const activityData = days.map((day, index) => ({
      period: day,
      trekkers: values[index]
    }));

    // Booking vs Cancellation data
    const bookingCancellationData = days.map((day, index) => ({
      period: day,
      bookings: bookingData.bookingValues[index],
      cancellations: bookingData.cancellationValues[index],
      netBookings: bookingData.bookingValues[index] - bookingData.cancellationValues[index]
    }));

    return {
      summary: summaryData,
      activity: activityData,
      bookings: bookingCancellationData
    };
  }, [timeFilter, customStartDate, customEndDate, days, values, metrics, bookingData]);

  // Export functions
  const handleExport = (format) => {
    setShowExportMenu(false);
    const exportData = prepareExportData;
    const fileName = `Mt_Hamiguitan_Reports_${dayjs().format('YYYY-MM-DD_HH-mm-ss')}`;
    
    if (format === 'excel') {
      exportToExcel(exportData, fileName);
    } else if (format === 'pdf') {
      exportToPDF(exportData, fileName);
    } else if (format === 'csv') {
      exportToCSV(exportData, fileName);
    }
  };

  // Export to Excel
  const exportToExcel = (data, fileName) => {
    try {
      const workbook = XLSX.utils.book_new();

      // Sheet 1: Summary Metrics
      const summarySheet = [
        ['Mt. Hamiguitan TrekScan - Reports Summary'],
        ['Generated:', dayjs().format('MMMM D, YYYY h:mm A')],
        [''],
        ['Period', data.summary.period],
        [''],
        ['Summary Metrics', ''],
        ['Total Trekkers', data.summary.totalTrekkers],
        ['Total Bookings', data.summary.totalBookings],
        ['Total Cancellations', data.summary.totalCancellations],
        ['Capacity Used', data.summary.capacityUsed],
        ['Average Group Size', data.summary.averageGroupSize],
        ['Peak Activity', data.summary.peakActivity],
        ['Most Popular Day', data.summary.mostPopularDay]
      ];
      const ws1 = XLSX.utils.aoa_to_sheet(summarySheet);
      XLSX.utils.book_append_sheet(workbook, ws1, 'Summary');

      // Sheet 2: Trekker Activity
      const activitySheet = [
        ['Period', 'Trekkers'],
        ...data.activity.map(item => [item.period, item.trekkers])
      ];
      const ws2 = XLSX.utils.aoa_to_sheet(activitySheet);
      XLSX.utils.book_append_sheet(workbook, ws2, 'Trekker Activity');

      // Sheet 3: Bookings vs Cancellations
      const bookingsSheet = [
        ['Period', 'Bookings', 'Cancellations', 'Net Bookings'],
        ...data.bookings.map(item => [
          item.period,
          item.bookings,
          item.cancellations,
          item.netBookings
        ])
      ];
      const ws3 = XLSX.utils.aoa_to_sheet(bookingsSheet);
      XLSX.utils.book_append_sheet(workbook, ws3, 'Bookings & Cancellations');

      // Write and download
      XLSX.writeFile(workbook, `${fileName}.xlsx`);
    } catch (error) {
      console.error('Error exporting to Excel:', error);
      alert('Error exporting to Excel. Please try again.');
    }
  };

  // Export to CSV
  const exportToCSV = (data, fileName) => {
    try {
      let csvContent = 'Mt. Hamiguitan TrekScan - Reports\n';
      csvContent += `Generated: ${dayjs().format('MMMM D, YYYY h:mm A')}\n`;
      csvContent += `Period: ${data.summary.period}\n\n`;

      // Summary Section
      csvContent += 'Summary Metrics\n';
      csvContent += `Total Trekkers,${data.summary.totalTrekkers}\n`;
      csvContent += `Total Bookings,${data.summary.totalBookings}\n`;
      csvContent += `Total Cancellations,${data.summary.totalCancellations}\n`;
      csvContent += `Capacity Used,${data.summary.capacityUsed}\n`;
      csvContent += `Average Group Size,${data.summary.averageGroupSize}\n`;
      csvContent += `Peak Activity,${data.summary.peakActivity}\n`;
      csvContent += `Most Popular Day,${data.summary.mostPopularDay}\n\n`;

      // Activity Section
      csvContent += 'Trekker Activity\n';
      csvContent += 'Period,Trekkers\n';
      data.activity.forEach(item => {
        csvContent += `${item.period},${item.trekkers}\n`;
      });
      csvContent += '\n';

      // Bookings Section
      csvContent += 'Bookings vs Cancellations\n';
      csvContent += 'Period,Bookings,Cancellations,Net Bookings\n';
      data.bookings.forEach(item => {
        csvContent += `${item.period},${item.bookings},${item.cancellations},${item.netBookings}\n`;
      });

      // Create blob and download
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      const url = URL.createObjectURL(blob);
      link.setAttribute('href', url);
      link.setAttribute('download', `${fileName}.csv`);
      link.style.visibility = 'hidden';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (error) {
      console.error('Error exporting to CSV:', error);
      alert('Error exporting to CSV. Please try again.');
    }
  };

  // Export to PDF
  const exportToPDF = (data, fileName) => {
    try {
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pageWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      let yPos = 20;
      const margin = 15;
      const lineHeight = 7;

      // Helper function to add new page if needed
      const checkNewPage = (requiredSpace) => {
        if (yPos + requiredSpace > pageHeight - margin) {
          pdf.addPage();
          yPos = margin;
        }
      };

      // Header
      pdf.setFontSize(18);
      pdf.setFont('helvetica', 'bold');
      pdf.text('Mt. Hamiguitan TrekScan - Reports', margin, yPos);
      yPos += lineHeight + 2;

      pdf.setFontSize(10);
      pdf.setFont('helvetica', 'normal');
      pdf.text(`Generated: ${dayjs().format('MMMM D, YYYY h:mm A')}`, margin, yPos);
      yPos += lineHeight;
      pdf.text(`Period: ${data.summary.period}`, margin, yPos);
      yPos += lineHeight + 5;

      // Summary Metrics
      checkNewPage(30);
      pdf.setFontSize(14);
      pdf.setFont('helvetica', 'bold');
      pdf.text('Summary Metrics', margin, yPos);
      yPos += lineHeight + 2;

      pdf.setFontSize(10);
      pdf.setFont('helvetica', 'normal');
      const summaryItems = [
        ['Total Trekkers', data.summary.totalTrekkers],
        ['Total Bookings', data.summary.totalBookings],
        ['Total Cancellations', data.summary.totalCancellations],
        ['Capacity Used', data.summary.capacityUsed],
        ['Average Group Size', data.summary.averageGroupSize],
        ['Peak Activity', data.summary.peakActivity],
        ['Most Popular Day', data.summary.mostPopularDay]
      ];

      summaryItems.forEach(([label, value]) => {
        checkNewPage(lineHeight);
        pdf.text(`${label}:`, margin, yPos);
        pdf.setFont('helvetica', 'bold');
        pdf.text(String(value), margin + 60, yPos);
        pdf.setFont('helvetica', 'normal');
        yPos += lineHeight;
      });

      yPos += 5;

      // Trekker Activity Table
      checkNewPage(30);
      pdf.setFontSize(14);
      pdf.setFont('helvetica', 'bold');
      pdf.text('Trekker Activity', margin, yPos);
      yPos += lineHeight + 2;

      pdf.setFontSize(9);
      pdf.setFont('helvetica', 'bold');
      pdf.text('Period', margin, yPos);
      pdf.text('Trekkers', margin + 80, yPos);
      yPos += lineHeight;
      pdf.setFont('helvetica', 'normal');

      data.activity.forEach(item => {
        checkNewPage(lineHeight);
        pdf.text(item.period, margin, yPos);
        pdf.text(String(item.trekkers), margin + 80, yPos);
        yPos += lineHeight;
      });

      yPos += 5;

      // Bookings vs Cancellations Table
      checkNewPage(30);
      pdf.setFontSize(14);
      pdf.setFont('helvetica', 'bold');
      pdf.text('Bookings vs Cancellations', margin, yPos);
      yPos += lineHeight + 2;

      pdf.setFontSize(9);
      pdf.setFont('helvetica', 'bold');
      pdf.text('Period', margin, yPos);
      pdf.text('Bookings', margin + 50, yPos);
      pdf.text('Cancellations', margin + 80, yPos);
      pdf.text('Net', margin + 115, yPos);
      yPos += lineHeight;
      pdf.setFont('helvetica', 'normal');

      data.bookings.forEach(item => {
        checkNewPage(lineHeight);
        pdf.text(item.period, margin, yPos);
        pdf.text(String(item.bookings), margin + 50, yPos);
        pdf.text(String(item.cancellations), margin + 80, yPos);
        pdf.text(String(item.netBookings), margin + 115, yPos);
        yPos += lineHeight;
      });

      // Save PDF
      pdf.save(`${fileName}.pdf`);
    } catch (error) {
      console.error('Error exporting to PDF:', error);
      alert('Error exporting to PDF. Please try again.');
    }
  };

  return (
    <LocalizationProvider dateAdapter={AdapterDayjs}>
      <div className="reports-main">
        {/* Header with Time Filter and Export */}
        <div className="reports-header">
          <div className="time-filter-container">
            <button
              className={`filter-btn ${timeFilter === 'daily' ? 'active' : ''}`}
              onClick={() => setTimeFilter('daily')}
            >
              Daily
            </button>
            <button
              className={`filter-btn ${timeFilter === 'weekly' ? 'active' : ''}`}
              onClick={() => setTimeFilter('weekly')}
            >
              Weekly
            </button>
            <button
              className={`filter-btn ${timeFilter === 'monthly' ? 'active' : ''}`}
              onClick={() => setTimeFilter('monthly')}
            >
              Monthly
            </button>
            <button
              className={`filter-btn ${timeFilter === 'custom' ? 'active' : ''}`}
              onClick={() => {
                setTimeFilter('custom');
                setShowCustomDatePicker(!showCustomDatePicker);
              }}
            >
              Custom Range
            </button>

            {timeFilter === 'custom' && (
              <div className="custom-date-picker">
                <DatePicker
                  label="Start Date"
                  value={customStartDate}
                  onChange={(newValue) => setCustomStartDate(newValue)}
                  slotProps={{ textField: { size: 'small' } }}
                />
                <DatePicker
                  label="End Date"
                  value={customEndDate}
                  onChange={(newValue) => setCustomEndDate(newValue)}
                  slotProps={{ textField: { size: 'small' } }}
                />
              </div>
            )}
          </div>

          <div className="export-container">
            <button
              className="export-btn"
              onClick={() => setShowExportMenu(!showExportMenu)}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M21 15V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V15M7 10L12 15M12 15L17 10M12 15V3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              Export
            </button>
            {showExportMenu && (
              <div className="export-dropdown">
                <div className="export-option" onClick={() => handleExport('excel')}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                    <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                    <line x1="16" y1="13" x2="8" y2="13" stroke="currentColor" strokeWidth="2"/>
                    <line x1="16" y1="17" x2="8" y2="17" stroke="currentColor" strokeWidth="2"/>
                    <polyline points="10,9 9,9 8,9" stroke="currentColor" strokeWidth="2"/>
                  </svg>
                  Export to Excel
                </div>
                <div className="export-option" onClick={() => handleExport('pdf')}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                    <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                  </svg>
                  Export to PDF
                </div>
                <div className="export-option" onClick={() => handleExport('csv')}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="2"/>
                    <polyline points="14,2 14,8 20,8" stroke="currentColor" strokeWidth="2"/>
                    <line x1="16" y1="13" x2="8" y2="13" stroke="currentColor" strokeWidth="2"/>
                    <line x1="16" y1="17" x2="8" y2="17" stroke="currentColor" strokeWidth="2"/>
                  </svg>
                  Export to CSV
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Key Metrics Cards */}
        <div className="reports-metrics-cards">
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
              <div className="metric-card-value-wrapper">
              <div className="metric-card-value">{loading ? '...' : metrics.totalTrekkers.toLocaleString()}</div>
                {!loading && metrics.trekkersChange !== 0 && (
                  <div className={`metric-card-comparison-inline ${metrics.trekkersChange > 0 ? 'comparison-positive' : 'comparison-negative'}`}>
                    {Math.abs(metrics.trekkersChange)}%
                    {metrics.trekkersChange > 0 ? '↑' : '↓'}
                  </div>
                )}
              </div>
              <div className="metric-card-label">Total Trekkers</div>
            </div>
          </div>

          <div className="metric-card">
            <div className="metric-card-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M9 11L12 14L22 4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M21 12V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value-wrapper">
              <div className="metric-card-value">{loading ? '...' : metrics.totalBookings.toLocaleString()}</div>
                {!loading && metrics.bookingsChange !== 0 && (
                  <div className={`metric-card-comparison-inline ${metrics.bookingsChange > 0 ? 'comparison-positive' : 'comparison-negative'}`}>
                    {Math.abs(metrics.bookingsChange)}%
                    {metrics.bookingsChange > 0 ? '↑' : '↓'}
                  </div>
                )}
              </div>
              <div className="metric-card-label">Total Bookings</div>
            </div>
          </div>

          <div className="metric-card">
            <div className="metric-card-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
                <path d="M15 9L9 15M9 9L15 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              </svg>
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value-wrapper">
              <div className="metric-card-value">{loading ? '...' : metrics.totalCancellations.toLocaleString()}</div>
                {!loading && metrics.cancellationsChange !== 0 && (
                  <div className={`metric-card-comparison-inline ${metrics.cancellationsChange > 0 ? 'comparison-positive' : 'comparison-negative'}`}>
                    {Math.abs(metrics.cancellationsChange)}%
                    {metrics.cancellationsChange > 0 ? '↑' : '↓'}
                  </div>
                )}
              </div>
              <div className="metric-card-label">Total Cancellations</div>
            </div>
          </div>

          <div className="metric-card">
            <div className="metric-card-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
                <path d="M3 9H21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                <path d="M9 3V21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              </svg>
            </div>
            <div className="metric-card-content">
              <div className="metric-card-value-wrapper">
              <div className="metric-card-value">{loading ? '...' : `${metrics.capacityUsed}%`}</div>
                {!loading && metrics.capacityChange !== 0 && (
                  <div className={`metric-card-comparison-inline ${metrics.capacityChange > 0 ? 'comparison-positive' : 'comparison-negative'}`}>
                    {Math.abs(metrics.capacityChange)}%
                    {metrics.capacityChange > 0 ? '↑' : '↓'}
                  </div>
                )}
              </div>
              <div className="metric-card-label">Capacity Used</div>
            </div>
          </div>
        </div>

        {/* Charts Section */}
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', lg: '1fr 1fr' }, gap: 2, mt: 2 }}>
          {/* Trekker Activity Trend */}
          <Card elevation={2} sx={{ borderRadius: 2, overflow: 'visible' }}>
            <div className="chart-gradient-bar"></div>
            <CardContent>
              <div className="chart-header">
                <div className="chart-title-section">
                  <div className="chart-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <path d="M3 12L7 8L12 12L17 7L21 11" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </div>
                  <div>
                    <Typography variant="h6" component="h2" className="chart-title">
                      Trekker Activity Trend
                    </Typography>
                    <Typography variant="body2" className="chart-subtitle">
                      Number of trekkers over the selected period
                    </Typography>
                  </div>
                </div>
              </div>

              <div className="trek-chart">
                <svg viewBox={`0 0 ${chartWidth} ${chartHeight}`} role="img" aria-label="Trekker Activity Line Chart">
                  <rect x="0" y="0" width={chartWidth} height={chartHeight} fill="#f9fafb" rx="8" />

                  {/* Grid lines */}
                  {Array.from({ length: 5 }, (_, i) => {
                    const y = padding.top + (innerH / 4) * i;
                    const value = Math.round(maxY - (maxY / 4) * i);
                    return (
                      <g key={`grid-${i}`}>
                        <line x1={padding.left} x2={chartWidth - padding.right} y1={y} y2={y} stroke="#eeeeee" strokeWidth="1" />
                        <text x={padding.left - 8} y={y + 4} textAnchor="end" className="axis-text">{value}</text>
                      </g>
                    );
                  })}

                  {/* X axis labels */}
                  {days.map((d, i) => {
                    if (i % Math.ceil(days.length / 8) === 0 || i === days.length - 1) {
                      return (
                        <text key={`x-${i}`} x={xAt(i)} y={chartHeight - 8} textAnchor="middle" className="axis-text">{d}</text>
                      );
                    }
                    return null;
                  })}

                  {/* Area fill */}
                  <path
                    d={`${pathD} L ${xAt(values.length - 1)} ${chartHeight - padding.bottom} L ${xAt(0)} ${chartHeight - padding.bottom} Z`}
                    fill="#e8f5e9"
                  />

                  {/* Line */}
                  <path d={pathD} fill="none" stroke="#30622f" strokeWidth="2.5" />

                  {/* Data points */}
                  {points.map(p => (
                    <circle
                      key={`pt-${p.i}`}
                      cx={p.x}
                      cy={p.y}
                      r={4}
                      fill="#30622f"
                      stroke="#ffffff"
                      strokeWidth="2"
                      onMouseEnter={() => setHover({ x: p.x, y: p.y, v: p.v, label: days[p.i] })}
                      onMouseLeave={() => setHover(null)}
                    />
                  ))}

                  {/* Axes */}
                  <line x1={padding.left} x2={padding.left} y1={padding.top} y2={chartHeight - padding.bottom} stroke="#e5e7eb" strokeWidth="1" />
                  <line x1={padding.left} x2={chartWidth - padding.right} y1={chartHeight - padding.bottom} y2={chartHeight - padding.bottom} stroke="#e5e7eb" strokeWidth="1" />
                </svg>

                {hover && (
                  <div
                    className="trek-tooltip"
                    style={{ left: hover.x, top: hover.y }}
                  >
                    <div className="trek-tooltip-date">{hover.label}</div>
                    <div className="trek-tooltip-value">{hover.v} trekkers</div>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Booking vs Cancellation Chart */}
          <Card elevation={2} sx={{ borderRadius: 2, overflow: 'visible' }}>
            <div className="chart-gradient-bar"></div>
            <CardContent>
              <div className="chart-header">
                <div className="chart-title-section">
                  <div className="chart-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                      <rect x="3" y="3" width="18" height="18" rx="2" stroke="white" strokeWidth="2"/>
                      <path d="M3 9H21" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                      <path d="M9 3V21" stroke="white" strokeWidth="2" strokeLinecap="round"/>
                    </svg>
                  </div>
                  <div>
                    <Typography variant="h6" component="h2" className="chart-title">
                      Bookings vs Cancellations
                    </Typography>
                    <Typography variant="body2" className="chart-subtitle">
                      Comparison of bookings and cancellations
                    </Typography>
                  </div>
                </div>
              </div>

              <div className="trek-chart">
                <svg viewBox={`0 0 ${barChartWidth} ${barChartHeight}`} role="img" aria-label="Booking vs Cancellation Bar Chart">
                  <rect x="0" y="0" width={barChartWidth} height={barChartHeight} fill="#f9fafb" rx="8" />

                  {/* Grid lines */}
                  {Array.from({ length: 5 }, (_, i) => {
                    const y = barPadding.top + (barInnerH / 4) * i;
                    const value = Math.round(barMaxY - (barMaxY / 4) * i);
                    return (
                      <g key={`bar-grid-${i}`}>
                        <line x1={barPadding.left} x2={barChartWidth - barPadding.right} y1={y} y2={y} stroke="#eeeeee" strokeWidth="1" />
                        <text x={barPadding.left - 8} y={y + 4} textAnchor="end" className="axis-text">{value}</text>
                      </g>
                    );
                  })}
                  
                  {/* Y-axis label */}
                  <text 
                    x={barPadding.left - 35} 
                    y={barPadding.top + barInnerH / 2} 
                    textAnchor="middle" 
                    className="axis-text"
                    transform={`rotate(-90 ${barPadding.left - 35} ${barPadding.top + barInnerH / 2})`}
                    style={{ fontSize: '12px', fill: '#6b7280' }}
                  >
                    Count
                  </text>

                  {/* Bars */}
                  {values.map((_, i) => {
                    const bookingValue = bookingData.bookingValues[i] || 0;
                    const cancelValue = bookingData.cancellationValues[i] || 0;
                    
                    const bookingY = barYAt(bookingValue);
                    const cancelY = barYAt(cancelValue);
                    const baseY = barPadding.top + barInnerH;
                    
                    const bookingHeight = Math.max(baseY - bookingY, 0);
                    const cancelHeight = Math.max(baseY - cancelY, 0);
                    
                    const centerX = barXAt(i);
                    const bookingX = centerX - barWidth - (barGap / 2);
                    const cancelX = centerX + (barGap / 2);

                    return (
                      <g key={`bars-${i}`}>
                        {/* Booking bar */}
                        <rect
                          x={bookingX}
                          y={bookingY}
                          width={barWidth}
                          height={bookingHeight}
                          fill="#30622f"
                          rx="2"
                          onMouseEnter={() => setBarHover({ 
                            x: centerX, 
                            y: bookingY - 10,
                            period: days[i],
                            bookings: bookingValue,
                            cancellations: cancelValue
                          })}
                          onMouseLeave={() => setBarHover(null)}
                          style={{ cursor: 'pointer' }}
                        />
                        {/* Cancellation bar */}
                        <rect
                          x={cancelX}
                          y={cancelY}
                          width={barWidth}
                          height={cancelHeight}
                          fill="#ef4444"
                          rx="2"
                          onMouseEnter={() => setBarHover({ 
                            x: centerX, 
                            y: cancelY - 10,
                            period: days[i],
                            bookings: bookingValue,
                            cancellations: cancelValue
                          })}
                          onMouseLeave={() => setBarHover(null)}
                          style={{ cursor: 'pointer' }}
                        />
                      </g>
                    );
                  })}

                  {/* X axis labels - adaptive spacing based on number of data points */}
                  {days.map((d, i) => {
                    // For daily (7 days): show all
                    // For weekly (7 weeks): show all or every other
                    // For monthly (12 months): show every 2-3 months
                    // For custom: show reasonable number based on total count
                    let showLabel = false;
                    const totalDays = days.length;
                    
                    if (totalDays <= 7) {
                      // Show all labels for 7 or fewer data points
                      showLabel = true;
                    } else if (totalDays <= 14) {
                      // Show every other label
                      showLabel = i % 2 === 0 || i === totalDays - 1;
                    } else if (totalDays <= 30) {
                      // Show every 3rd label, plus first and last
                      showLabel = i % 3 === 0 || i === 0 || i === totalDays - 1;
                    } else {
                      // Show approximately 10-12 labels
                      const step = Math.ceil(totalDays / 12);
                      showLabel = i % step === 0 || i === 0 || i === totalDays - 1;
                    }
                    
                    if (showLabel) {
                      return (
                        <text 
                          key={`bar-x-${i}`} 
                          x={barXAt(i)} 
                          y={barChartHeight - 8} 
                          textAnchor="middle" 
                          className="axis-text"
                          style={{ fontSize: totalDays > 20 ? '10px' : '12px' }}
                        >
                          {d}
                        </text>
                      );
                    }
                    return null;
                  })}

                  {/* Legend */}
                  <g>
                    <rect x={barChartWidth - 120} y={20} width="12" height="12" fill="#30622f" rx="2" />
                    <text x={barChartWidth - 100} y={30} className="axis-text" fontSize="12">Bookings</text>
                    <rect x={barChartWidth - 120} y={38} width="12" height="12" fill="#ef4444" rx="2" />
                    <text x={barChartWidth - 100} y={48} className="axis-text" fontSize="12">Cancellations</text>
                  </g>

                  {/* Axes */}
                  <line x1={barPadding.left} x2={barPadding.left} y1={barPadding.top} y2={barChartHeight - barPadding.bottom} stroke="#e5e7eb" strokeWidth="1" />
                  <line x1={barPadding.left} x2={barChartWidth - barPadding.right} y1={barChartHeight - barPadding.bottom} y2={barChartHeight - barPadding.bottom} stroke="#e5e7eb" strokeWidth="1" />
                </svg>

                {barHover && (
                  <div
                    className="bar-chart-tooltip"
                    style={{ 
                      left: `${(barHover.x / barChartWidth) * 100}%`,
                      top: `${(barHover.y / barChartHeight) * 100}%`
                    }}
                  >
                    <div className="bar-tooltip-period">{barHover.period}</div>
                    <div className="bar-tooltip-bookings">bookings : {barHover.bookings}</div>
                    <div className="bar-tooltip-cancellations">cancellations : {barHover.cancellations}</div>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </Box>

        {/* Additional Analytics */}
        <div className="analytics-cards">
          <Card elevation={2} sx={{ borderRadius: 2 }}>
            <CardContent sx={{ padding: '24px !important' }}>
              <div className="analytics-card-header">
                <Typography variant="h6" component="h2" className="analytics-card-title">
                  Peak Activity
                </Typography>
              </div>
              <div className="analytics-card-body">
                <div className="analytics-stat-item">
                  <span className="analytics-stat-label">Period:</span>
                  <span className="analytics-stat-value">{metrics.peakLabel}</span>
                </div>
                <div className="analytics-stat-item">
                  <span className="analytics-stat-label">Trekkers:</span>
                  <span className="analytics-stat-value">{metrics.peakValue}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card elevation={2} sx={{ borderRadius: 2 }}>
            <CardContent sx={{ padding: '24px !important' }}>
              <div className="analytics-card-header">
                <Typography variant="h6" component="h2" className="analytics-card-title">
                  Most Popular Day
                </Typography>
              </div>
              <div className="analytics-card-body">
                <div className="popular-day-chart">
                  {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day, index) => {
                    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                    const fullDayName = dayNames[index];
                    const dayCount = metrics.dayCounts?.[fullDayName] || 0;
                    const maxCount = Math.max(...Object.values(metrics.dayCounts || {}), 1);
                    const height = maxCount > 0 ? (dayCount / maxCount) * 100 : 0;
                    
                    // Progressive color gradient from light to vibrant green
                    const colors = [
                      { light: '#e8f5e9', dark: '#c8e6c9' }, // Very light green
                      { light: '#c8e6c9', dark: '#a5d6a7' }, // Light green
                      { light: '#a5d6a7', dark: '#81c784' }, // Medium light green
                      { light: '#81c784', dark: '#66bb6a' }, // Medium green
                      { light: '#66bb6a', dark: '#4caf50' }, // Medium-dark green
                      { light: '#4caf50', dark: '#30622f' }, // Dark green
                      { light: '#30622f', dark: '#30622f' }  // Vibrant green
                    ];
                    const colorSet = colors[index] || colors[colors.length - 1];
                    
                    return (
                      <div key={day} className="popular-day-bar-container">
                        <div 
                          className="popular-day-bar"
                          style={{ 
                            height: `${height}%`,
                            background: `linear-gradient(to top, ${colorSet.light}, ${colorSet.dark})`
                          }}
                        />
                        <span className="popular-day-label">{day}</span>
                      </div>
                    );
                  })}
                </div>
                <div className="analytics-average">
                  Average: {metrics.mostPopularDay}
                </div>
              </div>
            </CardContent>
          </Card>

          <Card elevation={2} sx={{ borderRadius: 2 }}>
            <CardContent sx={{ padding: '24px !important' }}>
              <div className="analytics-card-header">
                <Typography variant="h6" component="h2" className="analytics-card-title">
                  Average Group Size
                </Typography>
              </div>
              <div className="analytics-card-body">
                <div className="analytics-stat-item">
                  <span className="analytics-stat-label">Average:</span>
                  <span className="analytics-stat-value">{metrics.avgGroupSize}</span>
                </div>
                <div className="analytics-stat-item">
                  <span className="analytics-stat-label">Total Bookings:</span>
                  <span className="analytics-stat-value">{metrics.totalBookings.toLocaleString()}</span>
                </div>
                <div className="analytics-stat-item">
                  <span className="analytics-stat-label">Total Trekkers:</span>
                  <span className="analytics-stat-value">{metrics.totalTrekkers.toLocaleString()}</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Simple Analytics Section */}
        <div className="simple-analytics-section">
          <div className="simple-analytics-header">
            <Typography variant="h6" component="h2" className="simple-analytics-title">
              Analytics Overview
            </Typography>
            <Typography variant="body2" className="simple-analytics-subtitle">
              Averages and capacity based on {timeFilter === 'daily' ? 'daily' : timeFilter === 'weekly' ? 'weekly' : timeFilter === 'monthly' ? 'monthly' : 'custom'} filter
            </Typography>
          </div>
          <div className="simple-analytics-cards">
            <div className="analytics-metric-card">
              <div className="analytics-metric-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <path d="M17 21V19C17 17.9391 16.5786 16.9217 15.8284 16.1716C15.0783 15.4214 14.0609 15 13 15H5C3.93913 15 2.92172 15.4214 2.17157 16.1716C1.42143 16.9217 1 17.9391 1 19V21" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M9 11C11.2091 11 13 9.20914 13 7C13 4.79086 11.2091 3 9 3C6.79086 3 5 4.79086 5 7C5 9.20914 6.79086 11 9 11Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div className="analytics-metric-content">
                <div className="analytics-metric-value">{loading ? '...' : metrics.avgTrekkers}</div>
                <div className="analytics-metric-label">Average Trekkers</div>
              </div>
            </div>

            <div className="analytics-metric-card">
              <div className="analytics-metric-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <path d="M9 11L12 14L22 4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M21 12V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div className="analytics-metric-content">
                <div className="analytics-metric-value">{loading ? '...' : metrics.avgBookings}</div>
                <div className="analytics-metric-label">Average Bookings</div>
              </div>
            </div>

            <div className="analytics-metric-card">
              <div className="analytics-metric-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
                  <path d="M15 9L9 15M9 9L15 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                </svg>
              </div>
              <div className="analytics-metric-content">
                <div className="analytics-metric-value">{loading ? '...' : metrics.avgCancellations}</div>
                <div className="analytics-metric-label">Average Cancellations</div>
              </div>
            </div>

            <div className="analytics-metric-card">
              <div className="analytics-metric-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
                  <path d="M3 9H21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                  <path d="M9 3V21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                </svg>
              </div>
              <div className="analytics-metric-content">
                <div className="analytics-metric-value">{loading ? '...' : metrics.totalCapacity.toLocaleString()}</div>
                <div className="analytics-metric-label">Total Capacity</div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </LocalizationProvider>
  );
}

export default Reports;
