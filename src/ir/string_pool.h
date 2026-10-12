#pragma once
#include <string>
#include <unordered_set>
// currently no point of using arena style pooling but it works for now
// Arena-style string interning pool.  Deduplicates lexemes so that
// identical strings share a single allocation.  Returns stable
// const char* pointers that remain valid for the pool's lifetime.
//
// std::unordered_set guarantees pointer/iterator stability on insert,
// so the c_str()  of every stored string survives subsequent inserts.
class StringPool {
public:
    // Intern a C-string.  Returns a stable pointer to the pooled copy.
    // If the string already exists, no new allocation occurs.
    const char* intern(const char* s) {
        return pool_.emplace(s).first->c_str();
    }

    // Intern a std::string.
    const char* intern(const std::string& s) {
        return pool_.emplace(s).first->c_str();
    }

    // Number of unique strings currently pooled.
    size_t size() const { return pool_.size(); }

private:
    std::unordered_set<std::string> pool_;
};
