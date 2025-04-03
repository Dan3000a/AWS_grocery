import React from 'react';
import './Sidebar.css';

const Sidebar = ({ categories, priceRanges, filterByCategory, filterByPriceRange }) => {
  return (
    <div className="sidebar">
      <h3>Category</h3>
      <ul>
        <li>
          <button onClick={() => filterByCategory('All')}>
            All ({categories.reduce((sum, [, count]) => sum + count, 0)})
          </button>
        </li>
        {categories.map(([category, count]) => (
          <li key={category}>
            <button onClick={() => filterByCategory(category)}>
              {category} ({count})
            </button>
          </li>
        ))}
      </ul>

      <h3>Filter By Price</h3>
      <ul>
        <li>
          <button onClick={() => filterByPriceRange(null)}>
            All ({priceRanges.reduce((sum, [, count]) => sum + count, 0)})
          </button>
        </li>
        {priceRanges.map(([range, count]) => (
          <li key={range}>
            <button onClick={() => filterByPriceRange(range)}>
              {range} ({count})
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default Sidebar;