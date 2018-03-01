import FilteredSearchManager from '~/filtered_search/filtered_search_manager';

export default ({
  page,
  filteredSearchTokenKeys,
  isGroup,
  isGroupAncestor,
  stateFiltersSelector,
}) => {
  const filteredSearchEnabled = FilteredSearchManager && document.querySelector('.filtered-search');
  if (filteredSearchEnabled) {
    const filteredSearchManager = new FilteredSearchManager({
      page,
      isGroup,
      isGroupAncestor,
      filteredSearchTokenKeys,
      stateFiltersSelector,
    });
    filteredSearchManager.setup();
  }
};
