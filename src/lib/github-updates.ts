import type { AppConfig } from "./types";

/** La recherche auto n'a lieu qu'au démarrage, jamais en boucle ni à chaque onglet. */
export function doitVerifierAuDemarrage(config: Pick<AppConfig, "updatesAutoCheck" | "updatesConsentAnswered" | "updatesGithubRepo">): boolean {
  return config.updatesConsentAnswered && config.updatesAutoCheck && depotGitHubValide(config.updatesGithubRepo);
}

/** Ne pas envoyer de chemins, d'URLs et de tokens dans le nom de dépôt. */
export function depotGitHubValide(repository: string): boolean {
  return /^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,99}\/[a-zA-Z0-9][a-zA-Z0-9_.-]{0,99}$/.test(repository.trim());
}
