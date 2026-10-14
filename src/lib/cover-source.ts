/**
 * GameDraw 1.0.4 — source d'une jaquette avant passage à WebView2.
 * Ne jamais appliquer convertFileSrc() à une URL distante ou data:.
 * Une URL de script ou de protocole inconnu n'est pas une image.
 */
export type CoverSource =
  | { kind: "empty"; value: null }
  | { kind: "local" | "remote" | "inline"; value: string }
  | { kind: "invalid"; value: null };

export function classifyCoverSource(input: string | null | undefined): CoverSource {
  const value = input?.trim();
  if (!value) return { kind: "empty", value: null };
  if (/^https?:\/\//i.test(value)) return { kind: "remote", value };
  if (/^data:image\/(?:png|jpeg|jpg|webp|gif);base64,/i.test(value) || /^blob:/i.test(value)) {
    return { kind: "inline", value };
  }
  // Accepter les chemins Windows (C:\...) et les chemins absolus Unix.
  // Refuser javascript:, file:, ftp: et tout autre protocole inattendu.
  if (/^[a-z][a-z\d+.-]*:/i.test(value) && !/^[a-z]:[\\/]/i.test(value)) {
    return { kind: "invalid", value: null };
  }
  return { kind: "local", value };
}
