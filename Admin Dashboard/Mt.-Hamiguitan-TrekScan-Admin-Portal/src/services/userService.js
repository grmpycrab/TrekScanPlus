// User Service - Firebase operations for users
import { getDocumentById } from './firebaseService';
import UserModel from '../models/UserModel';

const COLLECTION_NAME = 'users';

/**
 * Get a user by ID
 * @param {string} userId - User ID
 * @returns {Promise<UserModel>} User model
 */
export const getUserById = async (userId) => {
  try {
    if (!userId) return null;
    
    const userData = await getDocumentById(COLLECTION_NAME, userId);
    return UserModel.fromMap({ id: userData.id, ...userData });
  } catch (error) {
    console.error(`Error getting user ${userId}:`, error);
    // Return null if user not found instead of throwing
    return null;
  }
};

/**
 * Get multiple users by IDs
 * @param {Array<string>} userIds - Array of user IDs
 * @returns {Promise<Array<UserModel>>} Array of user models
 */
export const getUsersByIds = async (userIds) => {
  try {
    if (!userIds || userIds.length === 0) return [];
    
    const userPromises = userIds.map(userId => getUserById(userId));
    const users = await Promise.all(userPromises);
    return users.filter(user => user !== null);
  } catch (error) {
    console.error('Error getting users:', error);
    return [];
  }
};

