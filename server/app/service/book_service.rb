# frozen_string_literal: true

require 'books_services_pb'

# Purpose: Service to handle books actions
class BookService < Books::BookService::Service
  def get_books(_request, _call)
    puts "incoming request for get_books"
    books = datas
    Books::Books.new(books:)
  end

  def get_book(request, _call)
    puts "incoming request for get_book"
    raise GRPC::Unavailable if request.id.to_i == 69

    books = datas
    book = books.find { |b| b['id'] == request.id }
    raise GRPC::NotFound, 'Book not found' if book.nil?

    Books::Book.new(book)
  end

  private

  def datas
    file = File.read('db/books.json')
    JSON.parse(file)
  end
end
