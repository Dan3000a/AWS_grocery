import React, { useState, useEffect } from 'react';
import { API_BASE_URL } from './config';
import ProductStore from './Component/ProductStore/ProductStore';

function App() {
  const [products, setProducts] = useState([]);
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [priceFilter, setPriceFilter] = useState(null);

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        console.log('Fetching products without params');
        const response = await fetch(`${API_BASE_URL}/api/products/all_products_products`);
        const data = await response.json();
        console.log('Products fetched:', data);
        setProducts(data);
      } catch (error) {
        console.error('Failed to fetch products:', error);
        setProducts([]);
      }
    };

    fetchProducts();
  }, []); // Remove categoryFilter and priceFilter from dependencies

  return (
    <div>
      <ProductStore
        products={products}
        setCategoryFilter={setCategoryFilter}
        setPriceFilter={setPriceFilter}
      />
    </div>
  );
}

export default App;