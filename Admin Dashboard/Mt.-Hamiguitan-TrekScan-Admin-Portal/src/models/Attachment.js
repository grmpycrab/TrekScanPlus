// Attachment Model - represents file attachment data
import { Timestamp } from 'firebase/firestore';

class Attachment {
  constructor(data = {}) {
    this.storagePath = data.storagePath || '';
    this.downloadURL = data.downloadURL || '';
    this.fileName = data.fileName || '';
    this.mimeType = data.mimeType || null;
    this.size = data.size || 0;
    this.uploadedAt = data.uploadedAt || Timestamp.now();
  }

  // Convert to Firestore-compatible map
  toMap() {
    return {
      storagePath: this.storagePath,
      downloadURL: this.downloadURL,
      fileName: this.fileName,
      mimeType: this.mimeType,
      size: this.size,
      uploadedAt: this.uploadedAt
    };
  }

  // Create from Firestore map
  static fromMap(map) {
    if (!map) return null;
    
    // Handle case where map might be a string (just URL) or object
    if (typeof map === 'string') {
      return new Attachment({
        downloadURL: map,
        fileName: map.split('/').pop() || 'file', // Extract filename from URL
        mimeType: null,
        size: 0,
        storagePath: '',
        uploadedAt: Timestamp.now()
      });
    }
    
    return new Attachment({
      storagePath: map.storagePath || '',
      downloadURL: map.downloadURL || map.url || '', // Support both downloadURL and url
      fileName: map.fileName || map.name || (map.downloadURL ? map.downloadURL.split('/').pop() : 'file'),
      mimeType: map.mimeType || map.type || null,
      size: typeof map.size === 'number' ? map.size : parseInt(map.size) || 0,
      uploadedAt: map.uploadedAt || Timestamp.now()
    });
  }

  // Convert to JSON (for API responses)
  toJSON() {
    return {
      storagePath: this.storagePath,
      downloadURL: this.downloadURL,
      fileName: this.fileName,
      mimeType: this.mimeType,
      size: this.size,
      uploadedAt: this.uploadedAt?.toDate?.()?.toISOString() || this.uploadedAt
    };
  }
}

export default Attachment;

