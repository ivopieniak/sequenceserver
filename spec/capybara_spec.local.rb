describe 'a browser', type: :feature, js: true do
  it 'properly controls blast button' do
    visit '/'

    fill_in('sequence', with: nucleotide_query)
    page.evaluate_script("$('#method').is(':disabled')").should eq(true)

    check(nucleotide_databases.first)
    page.evaluate_script("$('#method').is(':disabled')").should eq(false)
  end

  it 'properly controls interaction with database listing' do
    visit '/'
    fill_in('sequence', with: nucleotide_query)
    check(nucleotide_databases.first)
    page.evaluate_script("$('.protein .database').first().hasClass('disabled')")
      .should eq(true)
  end

  it 'shows a dropdown menu when other blast methods are available' do
    visit '/'
    fill_in('sequence', with: nucleotide_query)
    check(nucleotide_databases.first)
    page.save_screenshot('screenshot.png')
    page.has_css?('button.dropdown-toggle').should eq(true)
  end

  it 'can run a simple blastn search' do
    perform_search query: nucleotide_query,
      databases: nucleotide_databases
    page.should have_content('BLASTN')
  end

  it 'can run a simple blastp search' do
    perform_search query: protein_query,
      databases: protein_databases
    page.should have_content('BLASTP')
  end

  it 'can run a simple blastx search' do
    perform_search query: nucleotide_query,
      databases: protein_databases
    page.should have_content('BLASTX')
  end

  it 'can run a simple tblastx search' do
    perform_search query: nucleotide_query,
      databases: nucleotide_databases,
      method: 'tblastx'
    page.should have_content('TBLASTX')
  end

  it 'can run a simple tblastn search' do
    perform_search query: protein_query,
      databases: nucleotide_databases
    page.should have_content('TBLASTN')
  end

  ### Test aspects of the generated report.

  it 'can show hit sequences in a modal' do
    # Do a BLASTP search. protein_query refers to the first two sequence in
    # protein_databases[0], so the top hits are the query sequences themselves.
    perform_search(query: protein_query,
                   databases: protein_databases.values_at(0))

    # Click on the first sequence viewer link in the report.
    page.execute_script("$('.view-sequence:eq(0)').click()")

    within('.sequence-viewer') do
      page.should have_content('SI2.2.0_06267')
      page.should have_content(<<~SEQ.chomp)
        MNTLWLSLWDYPGKLPLNFMVFDTKDDLQAAYWRDPYSIP
        LAVIFEDPQPISQRLIYEIRTNPSYTLPPPPTKLYSAPIS
        CRKNKTGHWMDDILSIKTGESCPVNNYLHSGFLALQMITD
        ITKIKLENSDVTIPDIKLIMFPKEPYTADWMLAFRVVIPL
        YMVLALSQFITYLLILIVGEKENKIKEGMKMMGLNDSVF
      SEQ
    end

    # Dismiss the first modal.
    page.execute_script("$('.sequence-viewer').modal('hide')")

    # Click on the second sequence viewer link in the report.
    page.execute_script("$('.view-sequence:eq(1)').click()")

    within('.sequence-viewer') do
      page.should have_content('SI2.2.0_13722')
      page.should have_content(<<~SEQ.chomp)
        MSANRLNVLVTLMLAVALLVTESGNAQVDGYLQFNPKRSA
        VSSPQKYCGKKLSNALQIICDGVYNSMFKKSGQDFPPQNK
        RHIAHRINGNEEESFTTLKSNFLNWCVEVYHRHYRFVFVS
        EMEMADYPLAYDISPYLPPFLSRARARGMLDGRFAGRRYR
        RESRGIHEECCINGCTINELTSYCGP
      SEQ
    end
  end

  it "can download hit sequences" do
    # Do a BLASTP search. protein_query refers to the first two sequence in
    # protein_databases[0], so the top hits are the query sequences themselves.
    perform_search(query: protein_query,
                   databases: protein_databases.values_at(0))

    # Click on the first FASTA download button on the page and wait for the
    # download to finish.
    page.execute_script("$('.download-fa:eq(0)').click()")
    wait_for_download

    # Test name and content of the downloaded file.
    expect(File.basename(downloaded_file)).
      to eq('sequenceserver-SI2.2.0_06267.fa')
    expect(File.read(downloaded_file)).
      to eq(File.read("#{__dir__}/sequences/sequenceserver-SI2.2.0_06267.fa"))
  end

  it "can download alignment for each hit" do
    # Do a BLASTP search. protein_query refers to the first two sequence in
    # protein_databases[0], so the top hits are the query sequences themselves.
    perform_search(query: protein_query,
                   databases: protein_databases.values_at(0))

    # Click on the first Alignment download button on the page and wait for the
    # download to finish.
    page.execute_script("$('.download-aln:eq(0)').click()")
    wait_for_download

    # Test name and content of the downloaded file.
    expect(File.basename(downloaded_file)).to eq('Query_1_SI2_2_0_06267.txt')
    expect(File.read(downloaded_file)).
      to eq(File.read("#{__dir__}/sequences/Query_1_SI2_2_0_06267.txt"))
  end

  it 'disables sequence viewer links if hits are longer than 10kb' do
    # BLASTN transcripts against genome. nucleotide_query refers to two fire
    # ant transcripts and nucleotide_databases[0] is subset of the fire ant
    # genome (few longest scaffolds). We expect sequence viewer links to be
    # disabled for all hits of this search.
    perform_search(query: nucleotide_query,
                   databases: nucleotide_databases.values_at(0))

    # Check that the sequence viewer links are disabled.
    page.evaluate_script("$('.view-sequence').is(':disabled')").should eq(true)
  end

  ## Helpers ##

  def perform_search(query: , databases: , method: nil)
    # Load search form.
    visit '/'

    # Fill in query, select databases, submit form.
    fill_in('sequence', with: query)
    databases.each { |db| check db }
    if method == 'tblastx'
      find('.dropdown-toggle').click
      find('.dropdown-menu li').click
    end
    click_button('method')

    # Switch to new window because link opens in new window
    page.driver.browser.switch_to.window(page.driver.browser.window_handles.last)

    # It is important to have this line or the examples end prematurely with a
    # failure.
    page.should have_content('Query')
  end

  def nucleotide_query
    File.read File.join(__dir__, 'sequences', 'nucleotide_query.fa')
  end

  def protein_query
    File.read File.join(__dir__, 'sequences', 'protein_query.fa')
  end

  def nucleotide_databases
    [
      'Solenopsis invicta gnG subset',
      'Sinvicta 2-2-3 cdna subset'
    ]
  end

  def protein_databases
    [
      'Sinvicta 2-2-3 prot subset',
      '2018-04 Swiss-Prot insecta'
    ]
  end
end
