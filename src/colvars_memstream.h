// -*- c++ -*-

#ifndef MEMORY_STREAM_H
#define MEMORY_STREAM_H

#include <cstring>
#include <string>
#include <typeinfo>
#include <vector>

class cvm::memory_stream {

public:

  /// Set up an empty stream with an internal buffer, suitable for writing to
  /// \param max_length Maximum allowed capacity (default is 64 GiB)
  memory_stream(size_t max_length = (1L << 36)) : max_length_(max_length) {}

  /// Set up a stream based on an external input buffer
  memory_stream(size_t n, unsigned char const *buf)
    : external_input_buffer_(buf), internal_buffer_(), data_length_(n), max_length_(data_length_)
  {
  }

  /// Length of the buffer
  inline size_t length() const { return data_length_; }

  /// Output buffer
  inline unsigned char *output_buffer()
  {
    return (external_output_buffer_ ? external_output_buffer_ : internal_buffer_.data());
  }

  /// Next location to write to
  inline unsigned char *output_location() { return output_buffer() + data_length_; }

  /// Input buffer
  inline unsigned char const *input_buffer() const
  {
    return (external_input_buffer_ ? external_input_buffer_ : internal_buffer_.data());
  }

  /// Next location to read from
  inline unsigned char const *input_location() const { return input_buffer() + read_pos_; }

  /// Cast operator to be used to test for errors
  inline explicit operator bool() const { return error_code_ == 0; }

  /// Write a simple object to the output buffer
  template <typename T> void write_object(T const &t);

  /// Wrapper to write_object()
  template <typename T> friend memory_stream &operator<<(memory_stream &os, T const &t);

  /// Write a vector of simple objects to the output buffer
  template <typename T> void write_vector(std::vector<T> const &t);

  /// Wrapper to write_vector()
  template <typename T>
  friend memory_stream &operator<<(memory_stream &os, std::vector<T> const &t);

  /// Read a simple object from the buffer
  template <typename T> void read_object(T &t);

  /// Wrapper to read_object()
  template <typename T> friend memory_stream &operator>>(memory_stream &is, T &t);

  /// Read a vector of simple objects from the buffer
  template <typename T> void read_vector(std::vector<T> &t);

  /// Wrapper to read_vector()
  template <typename T> friend memory_stream &operator>>(memory_stream &is, std::vector<T> &t);

protected:

  /// External output buffer
  unsigned char *external_output_buffer_ = nullptr;

  /// External input buffer
  unsigned char const *external_input_buffer_ = nullptr;

  /// Internal buffer (may server for both input and output)
  std::vector<unsigned char> internal_buffer_;

  /// Length of the data buffer (either internal or external)
  size_t data_length_ = 0L;

  /// Largest allowed capacity of the data buffer
  size_t const max_length_;

  /// Error status
  int error_code_ = 0;

  /// Add the requester number of bytes to the array capacity; return false if buffer is external
  inline bool expand_ouput_buffer(size_t add_bytes)
  {
    if (external_output_buffer_) {
      // Cannot resize an external buffer
      error_code_ = 1;
    } else {
      if ((internal_buffer_.size() + add_bytes) <= max_length_) {
        internal_buffer_.resize((internal_buffer_.size() + add_bytes));
      } else {
        error_code_ = 1;
      }
    }
    return (error_code_ == 0);
  }

  /// Move the buffer position past the data just written
  inline void incr_write_pos(size_t c) { data_length_ += c; }

  /// Input buffer (may be the same as output, apart from const-ness)
  unsigned char const *input_buffer_ = nullptr;

  /// Current position when reading from the buffer
  size_t read_pos_ = 0L;

  /// Begin an attempt to read an object
  inline void begin_reading() { error_code_ = -1; }

  /// Mark the reading attempt succesful
  inline void done_reading() { error_code_ = 0; }

  /// Move the buffer position past the data just read
  inline void incr_read_pos(size_t c) { read_pos_ += c; }

  /// Check that the buffer contains enough bytes to read as the argument says, set error otherwise
  inline bool has_remaining(size_t c) { return c <= (data_length_ - read_pos_); }
};

template <typename T> void cvm::memory_stream::write_object(T const &t)
{
  static_assert(std::is_trivially_copyable<T>::value, "Cannot use write_object() on complex type");
  size_t const new_data_size = sizeof(T);
  if (expand_ouput_buffer(new_data_size)) {
    std::memcpy(output_location(), &t, sizeof(T));
    incr_write_pos(new_data_size);
  }
}

template <typename T> cvm::memory_stream &operator<<(cvm::memory_stream &os, T const &t)
{
  os.write_object<T>(t);
  return os;
}

template <> void cvm::memory_stream::write_object(std::string const &t)
{
  size_t const string_length = t.size();
  size_t const new_data_size = sizeof(size_t) + sizeof(char) * string_length;
  if (expand_ouput_buffer(new_data_size)) {
    std::memcpy(output_location(), &string_length, sizeof(size_t));
    incr_write_pos(sizeof(size_t));
    std::memcpy(output_location(), t.c_str(), t.size() * sizeof(char));
    incr_write_pos(t.size() * sizeof(char));
  }
}

template <> cvm::memory_stream &operator<<(cvm::memory_stream &os, std::string const &t)
{
  os.write_object<std::string>(t);
  return os;
}

template <> void cvm::memory_stream::write_object(cvm::vector1d<cvm::real> const &t)
{
  return write_vector<cvm::real>(t.data_array());
}

template <>
cvm::memory_stream &operator<<(cvm::memory_stream &os, cvm::vector1d<cvm::real> const &t)
{
  os.write_vector<cvm::real>(t.data_array());
  return os;
}

template <> void cvm::memory_stream::write_object(colvarvalue const &t) {}

template <> cvm::memory_stream &operator<<(cvm::memory_stream &os, colvarvalue const &t)
{
  os.write_object<colvarvalue>(t);
  return os;
}

template <typename T> void cvm::memory_stream::write_vector(std::vector<T> const &t)
{
  static_assert(std::is_trivially_copyable<T>::value, "Cannot use write_vector() on complex type");
  size_t const vector_length = t.size();
  size_t const new_data_size = sizeof(size_t) + sizeof(T) * vector_length;
  if (expand_ouput_buffer(new_data_size)) {
    std::memcpy(output_location(), &vector_length, sizeof(size_t));
    incr_write_pos(sizeof(T));
    std::memcpy(output_location(), t.data(), t.size() * sizeof(T));
    incr_write_pos(t.size() * sizeof(T));
  }
}

template <typename T>
cvm::memory_stream &operator<<(cvm::memory_stream &os, std::vector<T> const &t)
{
  os.write_vector<T>(t);
  return os;
}

template <typename T> void cvm::memory_stream::read_object(T &t)
{
  static_assert(std::is_trivially_copyable<T>::value, "Cannot use read_object() on complex type");
  begin_reading();
  if (has_remaining(sizeof(T))) {
    std::memcpy(&t, input_location(), sizeof(T));
    incr_read_pos(sizeof(T));
    done_reading();
  }
}

template <typename T> cvm::memory_stream &operator>>(cvm::memory_stream &is, T &t)
{
  is.read_object<T>(t);
  return is;
}

template <> void cvm::memory_stream::read_object(std::string &t)
{
  begin_reading();
  size_t string_length = 0;
  if (has_remaining(sizeof(size_t))) {
    std::memcpy(&string_length, input_location(), sizeof(size_t));
    incr_read_pos(sizeof(size_t));
    if (has_remaining(string_length * sizeof(char))) {
      t.assign(reinterpret_cast<char const *>(input_location()), string_length);
      incr_read_pos(string_length * sizeof(char));
      done_reading();
    }
  }
}

template <> cvm::memory_stream &operator>>(cvm::memory_stream &is, std::string &t)
{
  is.read_object<std::string>(t);
  return is;
}

template <> void cvm::memory_stream::read_object(cvm::vector1d<cvm::real> &t)
{
  return read_vector<cvm::real>(t.data_array());
}

template <> cvm::memory_stream &operator>>(cvm::memory_stream &is, cvm::vector1d<cvm::real> &t)
{
  is.read_vector<cvm::real>(t.data_array());
  return is;
}

template <typename T> void cvm::memory_stream::read_vector(std::vector<T> &t)
{
  static_assert(std::is_trivially_copyable<T>::value, "Cannot use read_vector() on complex type");
  begin_reading();
  size_t vector_length = 0;
  if (has_remaining(sizeof(size_t))) {
    std::memcpy(&vector_length, input_location(), sizeof(size_t));
    incr_read_pos(sizeof(size_t));
    if (has_remaining(vector_length * sizeof(T))) {
      t.resize(vector_length);
      std::memcpy(t.data(), input_location(), vector_length * sizeof(T));
      incr_read_pos(vector_length * sizeof(T));
      done_reading();
    }
  }
}

template <typename T> cvm::memory_stream &operator>>(cvm::memory_stream &is, std::vector<T> &t)
{
  is.read_vector<T>(t);
  return is;
}

#endif
