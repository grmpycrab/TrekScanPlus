/**
 * Export utilities for Climb Requests data
 * Supports CSV, Excel, and PDF formats
 */

/**
 * Export data to CSV format
 * @param {Array} data - Array of request objects
 * @param {string} filename - Name of the file to download
 */
export const exportToCSV = (data, filename = 'climb-requests') => {
  if (!data || data.length === 0) {
    throw new Error('No data to export');
  }

  // Define CSV headers
  const headers = [
    'ID',
    'Name',
    'Email',
    'Phone Number',
    'Age',
    'Affiliation',
    'Number of Porters',
    'Purpose of Climb',
    'Location',
    'Requested Date',
    'Date Submitted',
    'Status'
  ];

  // Convert data to CSV rows
  const rows = data.map(request => [
    request.id || request.requestId || '',
    request.name || '',
    request.email || '',
    request.phoneNumber || request.phone || '',
    request.age || '',
    request.affiliation || '',
    request.numberOfPorters || 0,
    request.purposeOfClimb || '',
    request.location || '',
    request.requestedDate || '',
    request.dateSubmitted || '',
    request.status || ''
  ]);

  // Combine headers and rows
  const csvContent = [
    headers.join(','),
    ...rows.map(row => 
      row.map(cell => {
        // Escape commas and quotes in cell values
        const cellValue = String(cell || '');
        if (cellValue.includes(',') || cellValue.includes('"') || cellValue.includes('\n')) {
          return `"${cellValue.replace(/"/g, '""')}"`;
        }
        return cellValue;
      }).join(',')
    )
  ].join('\n');

  // Create blob and download
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  
  link.setAttribute('href', url);
  link.setAttribute('download', `${filename}-${new Date().toISOString().split('T')[0]}.csv`);
  link.style.visibility = 'hidden';
  
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  
  URL.revokeObjectURL(url);
};

/**
 * Export data to Excel format
 * Requires: npm install xlsx
 * @param {Array} data - Array of request objects
 * @param {string} filename - Name of the file to download
 */
export const exportToExcel = async (data, filename = 'climb-requests') => {
  if (!data || data.length === 0) {
    throw new Error('No data to export');
  }

  try {
    // Dynamic import to handle case where library might not be installed
    const XLSX = await import('xlsx');
    
    // Prepare worksheet data
    const worksheetData = [
      // Headers
      [
        'Name',
        'Email',
        'Phone Number',
        'Age',
        'Affiliation',
        'Number of Porters',
        'Purpose of Climb',
        'Location',
        'Requested Date',
        'Date Submitted',
        'Status'
      ],
      // Data rows
      ...data.map(request => [
        request.name || '',
        request.email || '',
        request.phoneNumber || request.phone || '',
        request.age || '',
        request.affiliation || '',
        request.numberOfPorters || 0,
        request.purposeOfClimb || '',
        request.location || '',
        request.requestedDate || '',
        request.dateSubmitted || '',
        request.status || ''
      ])
    ];

    // Create workbook and worksheet
    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.aoa_to_sheet(worksheetData);

    // Set column widths
    worksheet['!cols'] = [
      { wch: 25 }, // Name
      { wch: 30 }, // Email
      { wch: 15 }, // Phone Number
      { wch: 5 },  // Age
      { wch: 20 }, // Affiliation
      { wch: 15 }, // Number of Porters
      { wch: 30 }, // Purpose of Climb
      { wch: 25 }, // Location
      { wch: 20 }, // Requested Date
      { wch: 20 }, // Date Submitted
      { wch: 12 }  // Status
    ];

    // Add worksheet to workbook
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Climb Requests');

    // Generate Excel file and download
    XLSX.writeFile(workbook, `${filename}-${new Date().toISOString().split('T')[0]}.xlsx`);
  } catch (error) {
    if (error.message.includes('Cannot find module') || error.message.includes('Failed to fetch')) {
      throw new Error('Excel export requires the xlsx library. Please install it with: npm install xlsx');
    }
    throw error;
  }
};

/**
 * Export data to PDF format
 * Requires: npm install jspdf
 * @param {Array} data - Array of request objects
 * @param {string} filename - Name of the file to download
 */
export const exportToPDF = async (data, filename = 'climb-requests') => {
  if (!data || data.length === 0) {
    throw new Error('No data to export');
  }

  try {
    // Dynamic import to handle case where library might not be installed
    const jsPDF = (await import('jspdf')).default;
    
    const doc = new jsPDF('landscape', 'mm', 'a4');
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();
    const margin = 10;
    const startY = 20;
    let yPos = startY;
    const rowHeight = 8;
    const maxRowsPerPage = Math.floor((pageHeight - startY - margin) / rowHeight);

    // Add title
    doc.setFontSize(16);
    doc.setFont(undefined, 'bold');
    doc.text('Climb Requests Report', margin, yPos);
    yPos += 10;

    // Add export date
    doc.setFontSize(10);
    doc.setFont(undefined, 'normal');
    doc.text(`Exported on: ${new Date().toLocaleString()}`, margin, yPos);
    doc.text(`Total Records: ${data.length}`, pageWidth - margin - 50, yPos);
    yPos += 10;

    // Table headers
    doc.setFontSize(9);
    doc.setFont(undefined, 'bold');
    const headers = ['Name', 'Email', 'Phone', 'Status', 'Date Submitted'];
    const colWidths = [40, 50, 35, 25, 40];
    let xPos = margin;

    // Draw header row
    headers.forEach((header, index) => {
      doc.rect(xPos, yPos - 5, colWidths[index], rowHeight);
      doc.text(header, xPos + 2, yPos);
      xPos += colWidths[index];
    });
    yPos += rowHeight;

    // Table data
    doc.setFont(undefined, 'normal');
    data.forEach((request, index) => {
      // Check if we need a new page
      if (index > 0 && index % maxRowsPerPage === 0) {
        doc.addPage();
        yPos = startY;
        
        // Redraw headers on new page
        xPos = margin;
        headers.forEach((header, hIndex) => {
          doc.setFont(undefined, 'bold');
          doc.rect(xPos, yPos - 5, colWidths[hIndex], rowHeight);
          doc.text(header, xPos + 2, yPos);
          xPos += colWidths[hIndex];
        });
        yPos += rowHeight;
        doc.setFont(undefined, 'normal');
      }

      xPos = margin;
      const rowData = [
        (request.name || '').substring(0, 20),
        (request.email || '').substring(0, 25),
        (request.phoneNumber || request.phone || '').substring(0, 15),
        (request.status || '').substring(0, 10),
        (request.dateSubmitted || '').substring(0, 20)
      ];

      rowData.forEach((cell, cellIndex) => {
        doc.rect(xPos, yPos - 5, colWidths[cellIndex], rowHeight);
        doc.text(cell, xPos + 2, yPos);
        xPos += colWidths[cellIndex];
      });
      yPos += rowHeight;
    });

    // Save PDF
    doc.save(`${filename}-${new Date().toISOString().split('T')[0]}.pdf`);
  } catch (error) {
    if (error.message.includes('Cannot find module') || error.message.includes('Failed to fetch')) {
      throw new Error('PDF export requires the jspdf library. Please install it with: npm install jspdf');
    }
    throw error;
  }
};

