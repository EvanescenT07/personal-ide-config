/** Joins truthy conditional CSS class names into a single space-separated string. */
export function cn(...values: Array<string | false | null | undefined>): string {
  return values.filter(Boolean).join(" ");
}
