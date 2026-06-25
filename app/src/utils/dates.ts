export function toDateString(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function daysBetween(dateStr1: string, dateStr2: string): number {
  const d1 = new Date(dateStr1 + 'T00:00:00');
  const d2 = new Date(dateStr2 + 'T00:00:00');
  const diff = Math.abs(d2.getTime() - d1.getTime());
  return Math.round(diff / (1000 * 60 * 60 * 24));
}

export function isWithinWindow(lastVisitDate: string, windowDays: number): boolean {
  const today = toDateString(new Date());
  return daysBetween(lastVisitDate, today) <= windowDays;
}

export function daysUntilExpiry(lastVisitDate: string, windowDays: number): number {
  const today = toDateString(new Date());
  return Math.max(0, windowDays - daysBetween(lastVisitDate, today));
}

export function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

export function formatDate(isoString: string): string {
  const d = new Date(isoString);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export function daysFromNow(isoString: string): number {
  const target = new Date(isoString + (isoString.includes('T') ? '' : 'T00:00:00'));
  const now = new Date();
  const diff = target.getTime() - now.getTime();
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

export function dateNDaysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return toDateString(d);
}

export function addDays(dateStr: string, n: number): string {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + n);
  return toDateString(d);
}
