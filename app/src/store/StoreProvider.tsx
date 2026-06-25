import React, { createContext, useContext, useReducer, useEffect, useCallback } from 'react';
import { User, Shop, Streak, Voucher, Visit, UserRole, VisitResult } from '../types';
import * as storage from './storage';
import { registerVisit } from '../services/streakService';

interface AppState {
  currentUser: User | null;
  currentRole: UserRole;
  shops: Shop[];
  streaks: Streak[];
  vouchers: Voucher[];
  visits: Visit[];
  isLoading: boolean;
  isInitialized: boolean;
}

type Action =
  | { type: 'SET_LOADING'; loading: boolean }
  | { type: 'INIT'; user: User; role: UserRole; shops: Shop[]; streaks: Streak[]; vouchers: Voucher[]; visits: Visit[] }
  | { type: 'SET_ROLE'; role: UserRole; user: User }
  | { type: 'RECORD_VISIT'; streak: Streak; newVouchers: Voucher[]; visit?: Visit }
  | { type: 'REDEEM_VOUCHER'; voucherId: string }
  | { type: 'UPDATE_SHOP'; shop: Shop }
  | { type: 'REFRESH'; streaks: Streak[]; vouchers: Voucher[]; visits: Visit[]; shops: Shop[] }
  | { type: 'UPDATE_USER'; user: User };

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, isLoading: action.loading };
    case 'INIT':
      return {
        ...state,
        currentUser: action.user,
        currentRole: action.role,
        shops: action.shops,
        streaks: action.streaks,
        vouchers: action.vouchers,
        visits: action.visits,
        isLoading: false,
        isInitialized: true,
      };
    case 'SET_ROLE':
      return { ...state, currentRole: action.role, currentUser: action.user };
    case 'RECORD_VISIT': {
      const streakIdx = state.streaks.findIndex(s => s.id === action.streak.id);
      const newStreaks = [...state.streaks];
      if (streakIdx >= 0) newStreaks[streakIdx] = action.streak;
      else newStreaks.push(action.streak);
      return {
        ...state,
        streaks: newStreaks,
        vouchers: [...state.vouchers, ...action.newVouchers],
      };
    }
    case 'REDEEM_VOUCHER':
      return {
        ...state,
        vouchers: state.vouchers.map(v =>
          v.id === action.voucherId
            ? { ...v, isRedeemed: true, redeemedAt: new Date().toISOString() }
            : v
        ),
      };
    case 'UPDATE_SHOP': {
      return {
        ...state,
        shops: state.shops.map(s => (s.id === action.shop.id ? action.shop : s)),
      };
    }
    case 'REFRESH':
      return { ...state, streaks: action.streaks, vouchers: action.vouchers, visits: action.visits, shops: action.shops };
    case 'UPDATE_USER':
      return { ...state, currentUser: action.user };
    default:
      return state;
  }
}

const initialState: AppState = {
  currentUser: null,
  currentRole: 'customer',
  shops: [],
  streaks: [],
  vouchers: [],
  visits: [],
  isLoading: true,
  isInitialized: false,
};

interface StoreContextType {
  state: AppState;
  switchRole: (role: UserRole) => Promise<void>;
  scanQR: (shopId: string) => Promise<VisitResult>;
  redeemVoucher: (voucherId: string) => Promise<void>;
  updateShop: (shop: Shop) => Promise<void>;
  updateUser: (user: User) => Promise<void>;
  refresh: () => Promise<void>;
  resetAll: () => Promise<void>;
}

const StoreContext = createContext<StoreContextType | null>(null);

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(reducer, initialState);

  const loadData = useCallback(async () => {
    await storage.initializeIfNeeded();
    const role = await storage.getCurrentRole();
    const userId = await storage.getCurrentUserId();
    const user = await storage.getUser(userId);
    const shops = await storage.getShops();
    const streaks = role === 'owner' ? await storage.getStreaks() : await storage.getStreaksForUser(userId);
    const vouchers = role === 'owner' ? await storage.getVouchers() : await storage.getVouchersForUser(userId);
    const visits = role === 'owner' ? await storage.getVisits() : await storage.getVisitsForUser(userId);
    dispatch({
      type: 'INIT',
      user: user!,
      role,
      shops,
      streaks,
      vouchers,
      visits,
    });
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const switchRole = useCallback(async (role: UserRole) => {
    await storage.setCurrentRole(role);
    const userId = await storage.getCurrentUserId();
    const user = await storage.getUser(userId);
    dispatch({ type: 'SET_ROLE', role, user: user! });
    const shops = await storage.getShops();
    const streaks = role === 'owner' ? await storage.getStreaks() : await storage.getStreaksForUser(userId);
    const vouchers = role === 'owner' ? await storage.getVouchers() : await storage.getVouchersForUser(userId);
    const visits = role === 'owner' ? await storage.getVisits() : await storage.getVisitsForUser(userId);
    dispatch({ type: 'REFRESH', streaks, vouchers, visits, shops });
  }, []);

  const scanQR = useCallback(async (shopId: string): Promise<VisitResult> => {
    const userId = await storage.getCurrentUserId();
    const result = await registerVisit(userId, shopId);
    if (result.status === 'success' && result.streak) {
      dispatch({
        type: 'RECORD_VISIT',
        streak: result.streak,
        newVouchers: result.newVouchers || [],
      });
    }
    return result;
  }, []);

  const handleRedeemVoucher = useCallback(async (voucherId: string) => {
    await storage.redeemVoucher(voucherId);
    dispatch({ type: 'REDEEM_VOUCHER', voucherId });
  }, []);

  const handleUpdateShop = useCallback(async (shop: Shop) => {
    await storage.updateShop(shop);
    dispatch({ type: 'UPDATE_SHOP', shop });
  }, []);

  const handleUpdateUser = useCallback(async (user: User) => {
    await storage.updateUser(user);
    dispatch({ type: 'UPDATE_USER', user });
  }, []);

  const refresh = useCallback(async () => {
    const role = await storage.getCurrentRole();
    const userId = await storage.getCurrentUserId();
    const shops = await storage.getShops();
    const streaks = role === 'owner' ? await storage.getStreaks() : await storage.getStreaksForUser(userId);
    const vouchers = role === 'owner' ? await storage.getVouchers() : await storage.getVouchersForUser(userId);
    const visits = role === 'owner' ? await storage.getVisits() : await storage.getVisitsForUser(userId);
    dispatch({ type: 'REFRESH', streaks, vouchers, visits, shops });
  }, []);

  const resetAll = useCallback(async () => {
    await storage.resetAllData();
    await loadData();
  }, [loadData]);

  return (
    <StoreContext.Provider
      value={{
        state,
        switchRole,
        scanQR,
        redeemVoucher: handleRedeemVoucher,
        updateShop: handleUpdateShop,
        updateUser: handleUpdateUser,
        refresh,
        resetAll,
      }}
    >
      {children}
    </StoreContext.Provider>
  );
}

export function useStore(): StoreContextType {
  const ctx = useContext(StoreContext);
  if (!ctx) throw new Error('useStore must be used within StoreProvider');
  return ctx;
}
