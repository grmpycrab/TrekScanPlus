// Booking Model - represents booking/trek request data
import { Timestamp } from 'firebase/firestore';
import Attachment from './Attachment';

class BookingModel {
  constructor(data = {}) {
    this.id = data.id || null;
    this.userId = data.userId || '';
    this.affiliation = data.affiliation || '';
    this.trekDate = data.trekDate || Timestamp.now();
    this.numberOfPorters = data.numberOfPorters || 0;
    this.trekType = data.trekType || 'general'; // recreational | research
    this.location = data.location || null; // inside_san_isidro | inside_davao_oriental | outside_davao_oriental
    this.phoneNumber = data.phoneNumber || null;
    this.notes = data.notes || null;
    this.adminNotes = data.adminNotes || null;
    this.attachments = data.attachments || [];
    this.status = data.status || 'pending';
    this.createdAt = data.createdAt || Timestamp.now();
    this.updatedAt = data.updatedAt || null;
  }

  // Convert to Firestore-compatible map
  toMap() {
    const map = {
      userId: this.userId,
      affiliation: this.affiliation,
      trekDate: this.trekDate,
      numberOfPorters: this.numberOfPorters,
      trekType: this.trekType,
      status: this.status,
      createdAt: this.createdAt,
      attachments: this.attachments.map(att => 
        att instanceof Attachment ? att.toMap() : Attachment.fromMap(att).toMap()
      )
    };

    if (this.id) {
      map.id = this.id;
    }
    if (this.location !== null && this.location !== undefined) {
      map.location = this.location;
    }
    if (this.phoneNumber) {
      map.phoneNumber = this.phoneNumber;
    }
    if (this.notes) {
      map.notes = this.notes;
    }
    if (this.adminNotes) {
      map.adminNotes = this.adminNotes;
    }
    if (this.updatedAt) {
      map.updatedAt = this.updatedAt;
    }

    return map;
  }

  // Create from Firestore document
  static fromDoc(doc) {
    if (!doc) return null;
    
    const data = doc.data ? doc.data() : doc;
    const docId = doc.id || data.id;

    return new BookingModel({
      id: docId,
      userId: data.userId || '',
      affiliation: data.affiliation || '',
      trekDate: data.trekDate || Timestamp.now(),
      numberOfPorters: typeof data.numberOfPorters === 'number' 
        ? data.numberOfPorters 
        : parseInt(data.numberOfPorters) || 0,
      trekType: data.trekType || 'recreational',
      location: (data.hometown !== null && data.hometown !== undefined) ? data.hometown : 
                ((data.location !== null && data.location !== undefined) ? data.location : null),
      phoneNumber: data.phoneNumber || null,
      notes: data.notes || null,
      adminNotes: data.adminNotes || null,
      attachments: (data.attachments || []).map(att => Attachment.fromMap(att)),
      status: data.status || 'pending',
      createdAt: data.createdAt || Timestamp.now(),
      updatedAt: data.updatedAt || null
    });
  }

  // Create from map (for API responses or manual construction)
  static fromMap(map) {
    if (!map) return null;

    return new BookingModel({
      id: map.id || null,
      userId: map.userId || '',
      affiliation: map.affiliation || '',
      trekDate: map.trekDate || Timestamp.now(),
      numberOfPorters: typeof map.numberOfPorters === 'number'
        ? map.numberOfPorters
        : parseInt(map.numberOfPorters) || 0,
      trekType: map.trekType || 'recreational',
      location: (map.hometown !== null && map.hometown !== undefined) ? map.hometown : 
                ((map.location !== null && map.location !== undefined) ? map.location : null),
      phoneNumber: map.phoneNumber || null,
      notes: map.notes || null,
      adminNotes: map.adminNotes || null,
      attachments: (map.attachments || []).map(att => Attachment.fromMap(att)),
      status: map.status || 'pending',
      createdAt: map.createdAt || Timestamp.now(),
      updatedAt: map.updatedAt || null
    });
  }

  // Convert to JSON (for API responses)
  toJSON() {
    return {
      id: this.id,
      userId: this.userId,
      affiliation: this.affiliation,
      trekDate: this.trekDate?.toDate?.()?.toISOString() || this.trekDate,
      numberOfPorters: this.numberOfPorters,
      trekType: this.trekType,
      location: this.location,
      phoneNumber: this.phoneNumber,
      notes: this.notes,
      adminNotes: this.adminNotes,
      attachments: this.attachments.map(att => 
        att instanceof Attachment ? att.toJSON() : att
      ),
      status: this.status,
      createdAt: this.createdAt?.toDate?.()?.toISOString() || this.createdAt,
      updatedAt: this.updatedAt?.toDate?.()?.toISOString() || this.updatedAt
    };
  }

  // Helper methods
  isPending() {
    return this.status === 'pending';
  }

  isApproved() {
    return this.status === 'approved';
  }

  isRejected() {
    return this.status === 'rejected';
  }

  isCancelled() {
    return this.status === 'cancelled';
  }

  isRecreational() {
    return this.trekType === 'recreational';
  }

  isResearch() {
    return this.trekType === 'research';
  }
}

export default BookingModel;

