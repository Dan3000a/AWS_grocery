import React, { useEffect, useState } from 'react';
import ProductGrid from './ProductGrid/ProductGrid';
import ProductHeader from './ProductHeader/ProductHeader';
import Sidebar from './Sidebar/Sidebar';
import './ProductStore.css';
import axios from 'axios';
import { API_BASE_URL } from '../../config';

const ProductStore = ({ products, isFav, basket, setBasket, setCategoryFilter, setPriceFilter }) => {
  const [filteredProducts, setFilteredProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [priceRanges, setPriceRanges] = useState([]);
  const [sortOption, setSortOption] = useState("Suggested");
  const [sortDirection, setSortDirection] = useState("asc");
  const [favProducts, setFavProducts] = useState([]);
  const [resetPage, setResetPage] = useState(false);

  useEffect(() => {
    const fetchFavorites = async () => {
      try {
        const token = localStorage.getItem('token');
        const response = await axios.get(`${API_BASE_URL}/api/me/favorites`, {
          headers: {
            Authorization: `Bearer ${token}`
          }
        });
        setFavProducts(response.data);
      } catch (error) {
        console.error('Failed to fetch favorites:', error);
      }
    };

    fetchFavorites();
  }, []);

  useEffect(() => {
    const calculateCategoriesAndPriceRanges = (products) => {
      const categoriesMap = {};
      const priceRangeMap = {
        '0€ - 5€': 0,
        '5€ - 10€': 0,
        '10€ - 20€': 0,
        '20€ - 50€': 0,
        '50€ - 100€': 0,
        '100€ - 200€': 0,
        '200€+': 0,
      };

      products.forEach(product => {
        // Category count
        if (categoriesMap[product.category]) {
          categoriesMap[product.category]++;
        } else {
          categoriesMap[product.category] = 1;
        }

        // Price range count
        if (product.price <= 5) {
          priceRangeMap['0€ - 5€']++;
        } else if (product.price <= 10) {
          priceRangeMap['5€ - 10€']++;
        } else if (product.price <= 20) {
          priceRangeMap['10€ - 20€']++;
        } else if (product.price <= 50) {
          priceRangeMap['20€ - 50€']++;
        } else if (product.price <= 100) {
          priceRangeMap['50€ - 100€']++;
        } else if (product.price <= 200) {
          priceRangeMap['100€ - 200€']++;
        } else {
          priceRangeMap['200€+']++;
        }
      });

      return {
        categories: Object.entries(categoriesMap),
        priceRanges: Object.entries(priceRangeMap)
      };
    };

    const { categories: productCategories, priceRanges: productPriceRanges } = calculateCategoriesAndPriceRanges(products);
    const { categories: favCategories, priceRanges: favPriceRanges } = calculateCategoriesAndPriceRanges(favProducts);

    setCategories(isFav ? favCategories : productCategories);
    setPriceRanges(isFav ? favPriceRanges : productPriceRanges);

    setFilteredProducts(isFav ? favProducts : products);
  }, [products, favProducts, isFav]);

  const filterByCategory = (category) => {
    setResetPage(prev => !prev);
    setCategoryFilter(category); // Update category filter in App.js
    const filtered = category && category !== 'All' ? (isFav ? favProducts : products).filter(product => product.category === category) : (isFav ? favProducts : products);
    setFilteredProducts(filtered);
    setSortOption("Suggested");
  };

  const filterByPriceRange = (range) => {
    setResetPage(prev => !prev);
    let priceFilter = null;
    if (range === '0€ - 5€') {
      priceFilter = { min: 0, max: 5 };
    } else if (range === '5€ - 10€') {
      priceFilter = { min: 5, max: 10 };
    } else if (range === '10€ - 20€') {
      priceFilter = { min: 10, max: 20 };
    } else if (range === '20€ - 50€') {
      priceFilter = { min: 20, max: 50 };
    } else if (range === '50€ - 100€') {
      priceFilter = { min: 50, max: 100 };
    } else if (range === '100€ - 200€') {
      priceFilter = { min: 100, max: 200 };
    } else if (range === '200€+') {
      priceFilter = { min: 200, max: Infinity };
    }
    setPriceFilter(priceFilter); // Update price filter in App.js
    const filtered = priceFilter ? (isFav ? favProducts : products).filter(product => {
      const min = priceFilter.min || 0;
      const max = priceFilter.max || Infinity;
      return product.price >= min && product.price <= max;
    }) : (isFav ? favProducts : products);
    setFilteredProducts(filtered);
    setSortOption("Suggested");
  };

  const sortProducts = (option) => {
    let sortedProducts = [...filteredProducts];
    let newSortDirection = sortDirection;

    if (option === "Suggested") {
      setFilteredProducts(isFav ? favProducts : products);
      setSortOption("Suggested");
      setSortDirection("asc");
      return;
    }

    if (option === sortOption) {
      newSortDirection = sortDirection === "asc" ? "desc" : "asc";
    } else {
      setSortOption(option);
      newSortDirection = "asc";
    }

    const directionMultiplier = newSortDirection === "asc" ? 1 : -1;
    if (option === "Name") {
      sortedProducts.sort((a, b) => a.name.localeCompare(b.name) * directionMultiplier);
    } else if (option === "Price") {
      sortedProducts.sort((a, b) => (a.price - b.price) * directionMultiplier);
    }

    setSortDirection(newSortDirection);
    setFilteredProducts(sortedProducts);
  };

  useEffect(() => {
    setFilteredProducts(isFav ? favProducts : products);
  }, [isFav, favProducts, products]);

  return (
    <div className="product-store-container">
      <Sidebar
        categories={categories}
        priceRanges={priceRanges}
        filterByCategory={filterByCategory}
        filterByPriceRange={filterByPriceRange}
      />
      <div className="main-content">
        <ProductHeader sortOption={sortOption} sortDirection={sortDirection} sortProducts={sortProducts} />
        <ProductGrid
          products={filteredProducts}
          isFav={isFav}
          basket={basket}
          setBasket={setBasket}
          filterByCategory={filterByCategory}
          resetPage={resetPage}
        />
      </div>
    </div>
  );
};

export default ProductStore;