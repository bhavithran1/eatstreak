export function generateVoucherCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 4; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return `EAT-${code}`;
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 8);
}

export function formatPercent(n: number): string {
  return `${n}%`;
}
