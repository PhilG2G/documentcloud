namespace :import do
  
  # NB: Oy. A rake task with both arguments and dependencies is an ugly little
  # bugger. Completely defeats the purpose of the DSL.
  # Usage: rake import:load_rdf[../wiki_news_rdf] --trace
  desc 'Load and save all RDF files from a directory of your choosing as Documents.'
  task :load_rdf, [:directory] => [:environment] do |t, args|
    file_names = Dir[args[:directory] + '/*.xml']
    file_names.each do |path|
      print "loading #{path}"
      doc = Document.new(:rdf => File.read(path))
      DC::Import::MetadataExtractor.new.extract_metadata(doc)
      doc.organization ||= Faker::Company.name
      puts " / saving as #{doc.id}"
      doc.save
    end
  end
  
  # Usage: rake import:load_pdf[../presidential_papers] --trace
  desc 'Load and save all PDF files from a directory of your choosing as Documents.'
  task :load_pdf, [:directory] => [:environment] do |t, args|
    file_names = Dir[args[:directory] + '/*.pdf']
    file_names.each do |path|
      print "loading #{path}"
      ex = DC::Import::TextExtractor.new(path)
      text, title = ex.get_text, (ex.get_title || "Untitled Document")
      if text.length > DC::Import::CalaisFetcher::MAX_TEXT_SIZE
        puts " / skipped because text length is #{text.length}"
        next
      end
      image_ex = DC::Import::ImageExtractor.new(path)
      image_ex.get_thumbnails
      doc = Document.new(
        :full_text            => text, 
        :title                => title, 
        :pdf_path             => path,
        :thumbnail_path       => image_ex.thumbnail_path,
        :small_thumbnail_path => image_ex.small_thumbnail_path
      )
      DC::Import::MetadataExtractor.new.extract_metadata(doc)
      doc.organization ||= Faker::Company.name
      puts " / saving as #{doc.id}"
      doc.save
    end
  end
  
  # Usage: rake import:dogpile_pdf[../congressional_documents] --trace
  desc 'Load and save all PDF files from a directory of your choosing via Dogpile.'
  task :dogpile_pdf, [:directory] => [:environment] do |t, args|
    urls = Dir[args[:directory] + "/*.pdf"].map {|pdf| "file://#{File.expand_path(pdf)}" }
    dp = DC::Import::DogpileImporter.new
    dp.import(urls)    
  end
  
  desc "completely wipe out all existing data stores"
  task :delete_databases => :environment do
    DC::Store::AssetStore.new.delete_database!
    DC::Store::EntryStore.new.delete_database!
    DC::Store::FullTextStore.new.delete_database!
    DC::Store::MetadataStore.new.delete_database!
  end
  
end