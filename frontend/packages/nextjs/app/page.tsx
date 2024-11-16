"use client";

import { useState } from "react";
import type { NextPage } from "next";
import { useAccount } from "wagmi";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [selectedTokenIn, setSelectedTokenIn] = useState("Select Token");
  const [selectedTokenOut, setSelectedTokenOut] = useState("Select Token");
  const [isDropdownInOpen, setIsDropdownInOpen] = useState(false);
  const [isDropdownOutOpen, setIsDropdownOutOpen] = useState(false);
  const [sliderValue, setSliderValue] = useState(25);

  const handleTokenInSelect = (token: string) => {
    setSelectedTokenIn(token);
    setIsDropdownInOpen(false);
  };

  const handleTokenOutSelect = (token: string) => {
    setSelectedTokenOut(token);
    setIsDropdownOutOpen(false);
  };

  return (
    <>
      <div>
        <div className="hero bg-base-200 min-h-screen">
          <div className="hero-content flex-col justify-center items-center">
            <div className="card bg-base-100 w-full max-w-sm shrink-0 shadow-2xl">
              <form className="card-body">
                <div className="form-control">
                  <div className="flex items-center gap-2">
                    {selectedTokenIn !== "Select Token" && (
                      selectedTokenIn === "WETH" ? (
                        <svg width="24" height="24" viewBox="0 0 32 32" className="shrink-0">
                          <g fill="none" fillRule="evenodd">
                            <circle cx="16" cy="16" r="16" fill="#627EEA"/>
                            <g fill="#FFF" fillRule="nonzero">
                              <path fillOpacity=".602" d="M16.498 4v8.87l7.497 3.35z"/>
                              <path d="M16.498 4L9 16.22l7.498-3.35z"/>
                              <path fillOpacity=".602" d="M16.498 21.968v6.027L24 17.616z"/>
                              <path d="M16.498 27.995v-6.028L9 17.616z"/>
                              <path fillOpacity=".2" d="M16.498 20.573l7.497-4.353-7.497-3.348z"/>
                              <path fillOpacity=".602" d="M9 16.22l7.498 4.353v-7.701z"/>
                            </g>
                          </g>
                        </svg>
                      ) : (
                        <svg width="24" height="24" viewBox="0 0 100 100" className="shrink-0">
                          <circle cx="50" cy="50" r="40" fill="#FF6B6B"/>
                          <text x="50" y="65" fontSize="40" fill="white" textAnchor="middle">B</text>
                        </svg>
                      )
                    )}
                    <div className="dropdown">
                      <div
                        tabIndex={0}
                        role="button"
                        className="btn m-1"
                        onClick={() => setIsDropdownInOpen(!isDropdownInOpen)}
                      >
                        {selectedTokenIn}
                      </div>
                      {isDropdownInOpen && (
                        <ul tabIndex={0} className="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow">
                          <li>
                            <a onClick={() => handleTokenInSelect("WETH")}>
                              <svg width="24" height="24" viewBox="0 0 32 32" className="shrink-0">
                                <g fill="none" fillRule="evenodd">
                                  <circle cx="16" cy="16" r="16" fill="#627EEA"/>
                                  <g fill="#FFF" fillRule="nonzero">
                                    <path fillOpacity=".602" d="M16.498 4v8.87l7.497 3.35z"/>
                                    <path d="M16.498 4L9 16.22l7.498-3.35z"/>
                                    <path fillOpacity=".602" d="M16.498 21.968v6.027L24 17.616z"/>
                                    <path d="M16.498 27.995v-6.028L9 17.616z"/>
                                    <path fillOpacity=".2" d="M16.498 20.573l7.497-4.353-7.497-3.348z"/>
                                    <path fillOpacity=".602" d="M9 16.22l7.498 4.353v-7.701z"/>
                                  </g>
                                </g>
                              </svg>
                              WETH
                            </a>
                          </li>
                          <li>
                            <a onClick={() => handleTokenInSelect("BOLD")}>
                              <svg width="16" height="16" viewBox="0 0 100 100" className="mr-2">
                                <circle cx="50" cy="50" r="40" fill="#FF6B6B"/>
                                <text x="50" y="65" fontSize="40" fill="white" textAnchor="middle">B</text>
                              </svg>
                              BOLD
                            </a>
                          </li>
                        </ul>
                      )}
                    </div>
                  </div>
                  <input type="number" placeholder="amount in" className="input input-bordered" required />
                </div>
                <div className="form-control">
                  <div className="flex items-center gap-2">
                    {selectedTokenOut !== "Select Token" && (
                      selectedTokenOut === "WETH" ? (
                        <svg width="24" height="24" viewBox="0 0 32 32" className="shrink-0">
                          <g fill="none" fillRule="evenodd">
                            <circle cx="16" cy="16" r="16" fill="#627EEA"/>
                            <g fill="#FFF" fillRule="nonzero">
                              <path fillOpacity=".602" d="M16.498 4v8.87l7.497 3.35z"/>
                              <path d="M16.498 4L9 16.22l7.498-3.35z"/>
                              <path fillOpacity=".602" d="M16.498 21.968v6.027L24 17.616z"/>
                              <path d="M16.498 27.995v-6.028L9 17.616z"/>
                              <path fillOpacity=".2" d="M16.498 20.573l7.497-4.353-7.497-3.348z"/>
                              <path fillOpacity=".602" d="M9 16.22l7.498 4.353v-7.701z"/>
                            </g>
                          </g>
                        </svg>
                      ) : (
                        <svg width="24" height="24" viewBox="0 0 100 100" className="shrink-0">
                          <circle cx="50" cy="50" r="40" fill="#FF6B6B"/>
                          <text x="50" y="65" fontSize="40" fill="white" textAnchor="middle">B</text>
                        </svg>
                      )
                    )}
                    <div className="dropdown">
                      <div
                        tabIndex={0}
                        role="button"
                        className="btn m-1"
                        onClick={() => setIsDropdownOutOpen(!isDropdownOutOpen)}
                      >
                        {selectedTokenOut}
                      </div>
                      {isDropdownOutOpen && (
                        <ul tabIndex={0} className="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow">
                          <li>
                            <a onClick={() => handleTokenOutSelect("WETH")}>
                              <svg width="24" height="24" viewBox="0 0 32 32" className="shrink-0">
                                <g fill="none" fillRule="evenodd">
                                  <circle cx="16" cy="16" r="16" fill="#627EEA"/>
                                  <g fill="#FFF" fillRule="nonzero">
                                    <path fillOpacity=".602" d="M16.498 4v8.87l7.497 3.35z"/>
                                    <path d="M16.498 4L9 16.22l7.498-3.35z"/>
                                    <path fillOpacity=".602" d="M16.498 21.968v6.027L24 17.616z"/>
                                    <path d="M16.498 27.995v-6.028L9 17.616z"/>
                                    <path fillOpacity=".2" d="M16.498 20.573l7.497-4.353-7.497-3.348z"/>
                                    <path fillOpacity=".602" d="M9 16.22l7.498 4.353v-7.701z"/>
                                  </g>
                                </g>
                              </svg>
                              WETH
                            </a>
                          </li>
                          <li>
                            <a onClick={() => handleTokenOutSelect("BOLD")}>
                              <svg width="16" height="16" viewBox="0 0 100 100" className="mr-2">
                                <circle cx="50" cy="50" r="40" fill="#FF6B6B"/>
                                <text x="50" y="65" fontSize="40" fill="white" textAnchor="middle">B</text>
                              </svg>
                              BOLD
                            </a>
                          </li>
                        </ul>
                      )}
                    </div>
                  </div>
                  <input type="number" placeholder="amount out" className="input input-bordered" required />
                </div>
                <div className="form-control mt-4">
                  <input 
                    type="range" 
                    min={0} 
                    max="100" 
                    value={sliderValue} 
                    onChange={(e) => setSliderValue(Number(e.target.value))} 
                    className="range" 
                    step="25" 
                  />
                  <div className="flex w-full justify-between px-2 text-xs">
                    <span>x2</span>
                    <span>x3</span>
                    <span>x4</span>
                    <span>x5</span>
                    <span>x10</span>
                  </div>
                </div>
                <div className="form-control mt-6">
                  <button className="btn btn-primary">Let's Luni Swap!</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
