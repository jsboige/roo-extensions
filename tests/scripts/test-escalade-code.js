/**
 * Règles de transformation appliquées aux données
 */
const rules = [
    { apply: (v) => v + 'a' },
    { apply: (v) => v.toUpperCase() },
    { apply: (v) => v.replace(/ /g, '_') }
];

/**
 * Transforme un élément selon des règles spécifiques
 * @param {Object} item - L'élément à transformer
 * @returns {Object} - L'élément transformé
 */
function transform(item) {
    return {
        ...item,
        value: item.value * 1.5,
        transformed: true
    };
}

/**
 * Modifie un élément enfant
 * @param {Object} child - L'élément enfant à modifier
 * @returns {Object} - L'élément enfant modifié
 */
function modify(child) {
    return {
        ...child,
        modified: true,
        timestamp: Date.now()
    };
}

/**
 * Traite les éléments de type A en filtrant les propriétés spéciales
 * @param {Object} item - L'élément à traiter
 * @returns {Array} - Tableau des propriétés spéciales traitées
 */
function processA(item) {
    return Object.entries(item.properties || {})
        .filter(([key]) => key.startsWith('special'))
        .map(([key, value]) => ({ key, value: value * 2 }));
}

/**
 * Traite les éléments de type B en filtrant les enfants actifs
 * @param {Object} item - L'élément à traiter
 * @returns {Array|null} - Tableau des enfants modifiés ou null
 */
function handleB(item) {
    const activeChildren = (item.children || [])
        .filter(child => child.active)
        .map(child => modify(child));
    
    return activeChildren.length > 0 ? activeChildren : null;
}

/**
 * Divise un élément en parties de taille fixe
 * @param {Object} item - L'élément à diviser
 * @returns {Array} - Tableau des parties
 */
function splitIntoParts(item) {
    const parts = [];
    const content = item.content || [];
    
    for (let n = 0; n < content.length; n += 10) {
        parts.push({
            slice: content.slice(n, n + 10),
            isValid: content[n] !== 'invalid'
        });
    }
    
    return parts;
}

/**
 * Applique des règles de transformation à une partie
 * @param {Object} part - La partie à transformer
 * @returns {*} - Le résultat transformé
 */
function applyRules(part) {
    return rules.reduce((result, rule) => rule.apply(result), part.slice);
}

/**
 * Aplatit une structure de données hiérarchique
 * @param {Object} item - L'élément à aplatir
 * @returns {Array} - Structure aplatie
 */
function flatten(item) {
    const flat = [];
    
    function recurse(current) {
        flat.push(current.value);
        if (current.children) {
            current.children.forEach(recurse);
        }
    }
    
    recurse(item);
    return flat;
}

/**
 * Traite les données de manière récursive mais avec une limite de profondeur
 * @param {Array} data - Les données à traiter
 * @param {number} depth - Profondeur actuelle de récursion
 * @returns {Array} - Résultats du traitement
 */
function processDataRecursively(data, depth = 0) {
    // Limite de récursion pour éviter les débordements de pile
    if (depth > 3 || !data || !data.length) {
        return [];
    }
    
    return data.flatMap(item => {
        if (item.type === 'B') {
            const res = handleB(item);
            return res ? processDataRecursively(res, depth + 1) : [];
        }
        return [];
    });
}

/**
 * Fonction principale refactorisée pour traiter des données complexes
 * @param {Array} data - Les données à traiter
 * @returns {Array} - Résultats du traitement
 */
function complexFunction(data) {
    if (!Array.isArray(data)) {
        return [];
    }
    
    // Résultat final
    let result = [];
    
    // Traitement par type
    data.forEach(item => {
        // Traitement des éléments de type A
        if (item.type === 'A') {
            const processedItems = processA(item);
            const validItems = processedItems
                .filter(subItem => subItem.value > 10)
                .map(transform);
            
            result.push(...validItems);
        }
        // Traitement des éléments de type B
        else if (item.type === 'B') {
            const res = handleB(item);
            if (res) {
                // Utilisation de la fonction sécurisée pour éviter la récursion infinie
                result.push(...processDataRecursively(res));
            }
        }
        // Traitement des éléments de type C
        else if (item.type === 'C') {
            const parts = splitIntoParts(item);
            const validParts = parts
                .filter(part => part.isValid)
                .map(applyRules);
            
            result.push(...validParts);
        }
        
        // Traitement des sous-données
        if (item.subData && item.subData.length > 3) {
            const deepItems = item.subData
                .filter(subItem => subItem.depth > 2)
                .map(flatten);
            
            result.push(...deepItems);
        }
    });
    
    return result;
}