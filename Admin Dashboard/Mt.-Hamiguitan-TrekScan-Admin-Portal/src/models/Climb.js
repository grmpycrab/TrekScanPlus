// Climb Model - represents climb/trek data
class Climb {
  constructor(data = {}) {
    this.id = data.id || null;
    this.name = data.name || '';
    this.date = data.date || new Date();
    this.dateBooked = data.dateBooked || null;
    this.targetDate = data.targetDate || null;
    this.dateApproved = data.dateApproved || null;
    this.type = data.type || 'General';
    this.status = data.status || 'Pending';
    this.documents = data.documents || [];
    this.adminNotes = data.adminNotes || null;
  }

  // Create from map (for Firestore or API responses)
  static fromMap(map) {
    if (!map) return null;

    let date;
    try {
      date = map.date instanceof Date 
        ? map.date 
        : new Date(map.date || '1970-01-01');
    } catch (_) {
      date = new Date(1970, 0, 1);
    }

    let dateBooked = null;
    try {
      if (map.dateBooked) {
        dateBooked = map.dateBooked instanceof Date
          ? map.dateBooked
          : new Date(map.dateBooked);
      }
    } catch (_) {
      dateBooked = null;
    }

    let targetDate = null;
    try {
      if (map.targetDate) {
        targetDate = map.targetDate instanceof Date
          ? map.targetDate
          : new Date(map.targetDate);
      }
    } catch (_) {
      targetDate = null;
    }

    let dateApproved = null;
    try {
      if (map.dateApproved) {
        dateApproved = map.dateApproved instanceof Date
          ? map.dateApproved
          : new Date(map.dateApproved);
      }
    } catch (_) {
      dateApproved = null;
    }

    return new Climb({
      id: map.id || null,
      name: map.name || '',
      date: date,
      dateBooked: dateBooked,
      targetDate: targetDate,
      dateApproved: dateApproved,
      type: map.type || 'General',
      status: map.status || 'Pending',
      documents: map.documents || [],
      adminNotes: map.adminNotes || null
    });
  }

  // Convert to map (for Firestore)
  toMap() {
    const map = {
      name: this.name,
      date: this.date instanceof Date 
        ? this.date.toISOString() 
        : this.date,
      type: this.type,
      status: this.status
    };

    if (this.id) {
      map.id = this.id;
    }
    if (this.dateBooked) {
      map.dateBooked = this.dateBooked instanceof Date
        ? this.dateBooked.toISOString()
        : this.dateBooked;
    }
    if (this.targetDate) {
      map.targetDate = this.targetDate instanceof Date
        ? this.targetDate.toISOString()
        : this.targetDate;
    }
    if (this.dateApproved) {
      map.dateApproved = this.dateApproved instanceof Date
        ? this.dateApproved.toISOString()
        : this.dateApproved;
    }
    if (this.adminNotes) {
      map.adminNotes = this.adminNotes;
    }
    if (this.documents && this.documents.length > 0) {
      map.documents = this.documents;
    }

    return map;
  }

  // Convert to JSON (for API responses)
  toJSON() {
    return {
      id: this.id,
      name: this.name,
      date: this.date instanceof Date ? this.date.toISOString() : this.date,
      dateBooked: this.dateBooked instanceof Date 
        ? this.dateBooked.toISOString() 
        : this.dateBooked,
      targetDate: this.targetDate instanceof Date 
        ? this.targetDate.toISOString() 
        : this.targetDate,
      dateApproved: this.dateApproved instanceof Date 
        ? this.dateApproved.toISOString() 
        : this.dateApproved,
      type: this.type,
      status: this.status,
      documents: this.documents,
      adminNotes: this.adminNotes
    };
  }

  // Compute status for display
  computedStatus() {
    const st = this.status.toLowerCase();
    
    if (st === 'cancelled') return 'Cancelled';
    
    const today = new Date();
    const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const climbDate = new Date(this.date);
    const climbDateOnly = new Date(climbDate.getFullYear(), climbDate.getMonth(), climbDate.getDate());
    
    if (climbDateOnly < todayDate) return 'Expired';
    
    // Capitalize status for display (e.g. 'approved' -> 'Approved')
    if (st.length === 0) return this.status;
    return st[0].toUpperCase() + st.substring(1);
  }

  // Helper methods
  isPending() {
    return this.status.toLowerCase() === 'pending';
  }

  isApproved() {
    return this.status.toLowerCase() === 'approved';
  }

  isRejected() {
    return this.status.toLowerCase() === 'rejected';
  }

  isCancelled() {
    return this.status.toLowerCase() === 'cancelled';
  }

  isExpired() {
    const today = new Date();
    const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const climbDate = new Date(this.date);
    const climbDateOnly = new Date(climbDate.getFullYear(), climbDate.getMonth(), climbDate.getDate());
    return climbDateOnly < todayDate;
  }
}

export default Climb;

