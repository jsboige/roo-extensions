// Déclaration de type pour permettre l'accès aux propriétés sur les objets de type unknown
declare global {
  interface Object {
    [key: string]: any;
  }
}

export {};