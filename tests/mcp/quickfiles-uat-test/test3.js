// JavaScript test file
function search() {
  return true;
}

function performSearch(query) {
  console.log('Searching for:', query);
  return search();
}

module.exports = { search, performSearch };