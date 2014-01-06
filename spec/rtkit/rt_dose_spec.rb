# encoding: ASCII-8BIT

require 'spec_helper'


module RTKIT

  describe RTDose do

    before :each do
      @ds = DataSet.new
      @p = Patient.new('John', '12345', @ds)
      @st = Study.new('1.456.789', @p)
      @f = Frame.new('1.4321', @p)
      @is = ImageSeries.new('1.987.3', 'CT', @f, @st)
      @ss = StructureSet.new('1.765.354', @is)
      @plan = Plan.new('1.456.654', @ss)
      @uid = '1.345.789'
      @date = '20050523'
      @time = '102219'
      @description = 'MC'
      @dose = RTDose.new(@uid, @plan)
    end

    describe "::load" do

      before :each do
        @dcm = DICOM::DObject.read(FILE_DOSE)
      end

      it "should raise an ArgumentError when a non-DObject is passed as the 'dcm' argument" do
        expect {RTDose.load(42, @st)}.to raise_error(ArgumentError, /'dcm'/)
      end

      it "should raise an ArgumentError when an non-Study is passed as the 'study' argument" do
        expect {RTDose.load(@dcm, 'not-a-study')}.to raise_error(ArgumentError, /study/)
      end

      it "should raise an ArgumentError when a DObject with a non-plan modality is passed with the 'dcm' argument" do
        expect {RTDose.load(DICOM::DObject.read(FILE_IMAGE), @st)}.to raise_error(ArgumentError, /'dcm'/)
      end

      it "should create a RTDose instance with attributes taken from the DICOM Object" do
        dose = RTDose.load(@dcm, @st)
        expect(dose.series_uid).to eql @dcm.value('0020,000E')
        expect(dose.modality).to eql @dcm.value('0008,0060')
        expect(dose.class_uid).to eql @dcm.value('0008,0016')
        expect(dose.date).to eql @dcm.value('0008,0021')
        expect(dose.time).to eql @dcm.value('0008,0031')
        expect(dose.description).to eql @dcm.value('0008,103E')
      end

      it "should create a RTDose instance which is properly referenced to its study" do
        dose = RTDose.load(@dcm, @st)
        expect(dose.study).to eql @st
      end

      it "should set up a Plan reference when no corresponding Plan have been loaded" do
        dose = RTDose.load(@dcm, @st)
        expect(dose.plan).to be_a Plan
      end

      it "should ignore the 'empty' dose volume amongst the three 'real volumes' (in this case exported from the Oncentra TPS)" do
        ds = DataSet.read(DIR_SIMPLE_PHANTOM_CASE)
        dose = ds.patient.study.iseries.struct.plan.rt_dose
        # This case contains 3 beams and 3 corresponding dose volumes, and an additional 'empty' volume:
        expect(dose.volumes.length).to eql 3
      end

      it "should ignore the single 'empty' dose volume (in this case exported from the Oncentra TPS)" do
        dcm = DICOM::DObject.read(FILE_EMPTY_DOSE)
        dose = RTDose.load(dcm, @st)
        expect(dose.volumes.length).to eql 0
      end

    end


    context "::new" do

      it "should raise an ArgumentError when a non-string is passed as the 'series_uid' argument" do
        expect {RTDose.new(42, @plan)}.to raise_error(ArgumentError, /'series_uid'/)
      end

      it "should raise an ArgumentError when a non-Plan is passed as the 'plan' argument" do
        expect {RTDose.new(@uid, 'not-a-plan')}.to raise_error(ArgumentError, /'plan'/)
      end

      it "should by default set the 'volumes' attribute as an empty array" do
        expect(@dose.volumes).to eql Array.new
      end

      it "should by default set the 'modality' attribute equal as 'RTDOSE'" do
        expect(@dose.modality).to eql 'RTDOSE'
      end

      it "should by default set the 'class_uid' attribute equal to the RT Dose Storage Class UID" do
        expect(@dose.class_uid).to eql '1.2.840.10008.5.1.4.1.1.481.2'
      end

      it "should by default set the 'date' attribute as nil" do
        expect(@dose.date).to be_nil
      end

      it "should by default set the 'time' attribute as nil" do
        expect(@dose.time).to be_nil
      end

      it "should by default set the 'description' attribute as nil" do
        expect(@dose.description).to be_nil
      end

      it "should pass the 'series_uid' argument to the 'series_uid' attribute" do
        expect(@dose.series_uid).to eql @uid
      end

      it "should pass the 'plan' argument to the 'plan' attribute" do
        expect(@dose.plan).to eql @plan
      end

      it "should pass the optional 'date' argument to the 'date' attribute" do
        dose = RTDose.new(@uid, @plan, :date => @date)
        expect(dose.date).to eql @date
      end

      it "should pass the optional 'time' argument to the 'time' attribute" do
        dose = RTDose.new(@uid, @plan, :time => @time)
        expect(dose.time).to eql @time
      end

      it "should pass the optional 'description' argument to the 'description' attribute" do
        dose = RTDose.new(@uid, @plan, :description => @description)
        expect(dose.description).to eql @description
      end

      it "should add the Dose instance (once) to the referenced Plan" do
        expect(@dose.plan.rt_doses.length).to eql 1
        expect(@dose.plan.rt_doses.first).to eql @dose
      end

    end


    context "#==()" do

      it "should be true when comparing two instances having the same attribute values" do
        dose_other = RTDose.new(@uid, @plan)
        expect(@dose == dose_other).to be_true
      end

      it "should be false when comparing two instances having different attributes" do
        dose_other = RTDose.new('1.7.99', @plan)
        expect(@dose == dose_other).to be_false
      end

      it "should be false when comparing against an instance of incompatible type" do
        expect(@dose == 42).to be_false
      end

    end


    context "#add_volume" do

      it "should raise an ArgumentError when a non-DoseVolume is passed as the 'volume' argument" do
        expect {@dose.add_volume('not-a-dose-volume')}.to raise_error(ArgumentError, /'volume'/)
      end

      it "should add the Volume to the volume-less RTDose instance" do
        dose_other = RTDose.new('1.23.787', @plan)
        vol = DoseVolume.new('1.45.876', @f, dose_other)
        @dose.add_volume(vol)
        expect(@dose.volumes.size).to eql 1
        expect(@dose.volumes.first).to eql vol
      end

      it "should add the Volume to the RTDose instance already containing one or more volumes" do
        ds = DataSet.read(DIR_DOSE_ONLY)
        dose = ds.patient.study.iseries.struct.plan.rt_dose
        previous_size = dose.volumes.size
        vol = DoseVolume.new('1.45.876', @f, @dose)
        dose.add_volume(vol)
        expect(dose.volumes.size).to eql previous_size + 1
        expect(dose.volumes.last).to eql vol
      end

      it "should not add multiple entries of the same DoseVolume" do
        vol = DoseVolume.new('1.45.876', @f, @dose)
        @dose.add_volume(vol)
        expect(@dose.volumes.size).to eql 1
        expect(@dose.volumes.first).to eql vol
      end

    end


    context "#eql?" do

      it "should be true when comparing two instances having the same attribute values" do
        dose_other = RTDose.new(@uid, @plan)
        expect(@dose.eql?(dose_other)).to be_true
      end

      it "should be false when comparing two instances having different attribute values" do
        dose_other = RTDose.new('1.7.99', @plan)
        expect(@dose.eql?(dose_other)).to be_false
      end

    end


    context "#hash" do

      it "should return the same Fixnum for two instances having the same attribute values" do
        dose_other = RTDose.new(@uid, @plan)
        expect(@dose.hash).to be_a Fixnum
        expect(@dose.hash).to eql dose_other.hash
      end

      it "should return a different Fixnum for two instances having different attribute values" do
        dose_other = RTDose.new('1.7.99', @plan)
        expect(@dose.hash).not_to eql dose_other.hash
      end

    end


    context "#sum" do

      before :each do
        @vol1 = DoseVolume.new('1.23.787', @f, @dose)
        @vol2 = DoseVolume.new('1.45.876', @f, @dose)
        @vol1.scaling = 2.0
        @vol2.scaling = 3.0
        @cols = 2
        @rows = 3
        @i11 = SliceImage.new('1.67.11', 0.0, @vol1)
        @i12 = SliceImage.new('1.67.12', 2.0, @vol1)
        @i21 = SliceImage.new('1.67.21', 4.0, @vol2)
        @i22 = SliceImage.new('1.67.23', 6.0, @vol2)
        @i11.columns = @cols
        @i12.columns = @cols
        @i21.columns = @cols
        @i22.columns = @cols
        @i11.rows = @rows
        @i12.rows = @rows
        @i21.rows = @rows
        @i22.rows = @rows
        @i11.narray = NArray.int(@cols, @rows).indgen!
        @i12.narray = NArray.int(@cols, @rows).indgen!
        @i21.narray = NArray.int(@cols, @rows).fill(1)
        @i22.narray = NArray.int(@cols, @rows).fill(2)
      end

      it "should return a DoseVolume which is a proper sum of the beam dose volumes" do
        sum = @dose.sum
        expect(sum.class).to eql DoseVolume
        expect(sum.images.length).to eql 2
        expect(sum.scaling).to be_a Float
        expect(sum.scaling).to be > 0.0
        expect(sum.narray.shape).to eql @vol1.narray.shape
        # Because of float precision we can't expect perfect equality. We are satisfied if the result is within a small threshold:
        expect((sum.dose_arr - (@vol1.dose_arr + @vol2.dose_arr)).abs.max).to be < 0.001
      end

    end


    context "#to_rt_dose" do

      it "should return itself" do
        expect(@dose.to_rt_dose.equal?(@dose)).to be_true
      end

    end


    context "#volume" do

      before :each do
        @uid1 = '1.23.787'
        @uid2 = '1.45.876'
        @vol1 = DoseVolume.new(@uid1, @f, @dose)
        @vol2 = DoseVolume.new(@uid2, @f, @dose)
      end

      it "should raise an ArgumentError when a non-String is passed as an argument" do
        expect {@dose.volume(42)}.to raise_error(ArgumentError, /String/)
      end

      it "should raise an ArgumentError if multiple arguments are passed" do
        expect {@dose.volume(@uid1, @uid2)}.to raise_error(ArgumentError, /one/)
      end

      it "should return the first DoseVolume when no arguments are used" do
        expect(@dose.volume).to eql @dose.volumes.first
      end

      it "should return the matching DoseVolume when a UID string is supplied" do
        vol = @dose.volume(@uid2)
        expect(vol.uid).to eql @uid2
      end

    end

  end

end