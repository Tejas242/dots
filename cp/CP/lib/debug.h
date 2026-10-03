#ifndef DEBUG_H
#define DEBUG_H

#include <iostream>
#include <vector>
#include <string>
#include <set>
#include <map>
#include <algorithm>

using namespace std;

// --- Primitive Types ---
void __print(int x) { cerr << x; }
void __print(long x) { cerr << x; }
void __print(long long x) { cerr << x; }
void __print(unsigned x) { cerr << x; }
void __print(unsigned long x) { cerr << x; }
void __print(unsigned long long x) { cerr << x; }
void __print(float x) { cerr << x; }
void __print(double x) { cerr << x; }
void __print(long double x) { cerr << x; }
void __print(char x) { cerr << '\'' << x << '\''; }
void __print(const char *x) { cerr << '\"' << x << '\"'; }
void __print(const string &x) { cerr << '\"' << x << '\"'; }
void __print(bool x) { cerr << (x ? "true" : "false"); }

// --- Complex Types Forward Declarations ---
template<typename T, typename V>
void __print(const pair<T, V> &x);

template<typename T>
void __print(const T &x);

// --- Complex Types Implementations ---
template<typename T, typename V>
void __print(const pair<T, V> &x) {
    cerr << '{';
    __print(x.first);
    cerr << ", ";
    __print(x.second);
    cerr << '}';
}

template<typename T>
void __print(const T &x) {
    int f = 0;
    cerr << '{';
    for (auto &i : x) {
        cerr << (f++ ? ", " : "");
        __print(i);
    }
    cerr << "}";
}

// --- Variadic Logic ---
void _print() {
    cerr << "]\n";
}

template <typename T, typename... V>
void _print(T t, V... v) {
    __print(t);
    if (sizeof...(v)) cerr << ", ";
    _print(v...);
}

// --- The Macro ---
// Prints the variable names and their values
#define debug(x...) cerr << "[" << #x << "] = ["; _print(x)

#endif // DEBUG_H
