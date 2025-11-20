import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finzobilling/widgets/gstin_input_field.dart';

class AddEditSupplierScreen extends StatefulWidget {
  final String? supplierId;
  final Map<String, dynamic>? supplierData;

  const AddEditSupplierScreen({
    super.key,
    this.supplierId,
    this.supplierData,
  });

  @override
  State<AddEditSupplierScreen> createState() => _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState extends State<AddEditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _selectedState = 'Karnataka';
  String? _selectedDistrict;  // ✅ NEW
  bool _isSaving = false;

  final Map<String, String> _indianStates = {
    'Andhra Pradesh': '37',
    'Arunachal Pradesh': '12',
    'Assam': '18',
    'Bihar': '10',
    'Chhattisgarh': '22',
    'Goa': '30',
    'Gujarat': '24',
    'Haryana': '06',
    'Himachal Pradesh': '02',
    'Jharkhand': '20',
    'Karnataka': '29',
    'Kerala': '32',
    'Madhya Pradesh': '23',
    'Maharashtra': '27',
    'Manipur': '14',
    'Meghalaya': '17',
    'Mizoram': '15',
    'Nagaland': '13',
    'Odisha': '21',
    'Punjab': '03',
    'Rajasthan': '08',
    'Sikkim': '11',
    'Tamil Nadu': '33',
    'Telangana': '36',
    'Tripura': '16',
    'Uttar Pradesh': '09',
    'Uttarakhand': '05',
    'West Bengal': '19',
    'Delhi': '07',
    'Puducherry': '34',
  };

  // ✅ SAME district data as client screen
  final Map<String, List<String>> _stateDistricts = {
    'Karnataka': ['Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural', 'Bengaluru Urban', 'Bidar', 'Chamarajanagar', 'Chikkaballapur', 'Chikkamagaluru', 'Chitradurga', 'Dakshina Kannada', 'Davanagere', 'Dharwad', 'Gadag', 'Hassan', 'Haveri', 'Kalaburagi', 'Kodagu', 'Kolar', 'Koppal', 'Mandya', 'Mysuru', 'Raichur', 'Ramanagara', 'Shivamogga', 'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayapura', 'Yadgir'],
    'Maharashtra': ['Ahmednagar', 'Akola', 'Amravati', 'Aurangabad', 'Beed', 'Bhandara', 'Buldhana', 'Chandrapur', 'Dhule', 'Gadchiroli', 'Gondia', 'Hingoli', 'Jalgaon', 'Jalna', 'Kolhapur', 'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur', 'Nanded', 'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani', 'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara', 'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim', 'Yavatmal'],
    'Tamil Nadu': ['Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kanchipuram', 'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai', 'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai', 'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi', 'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli', 'Tirupathur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore', 'Viluppuram', 'Virudhunagar'],
    'Uttar Pradesh': ['Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha', 'Auraiya', 'Ayodhya', 'Azamgarh', 'Baghpat', 'Bahraich', 'Ballia', 'Balrampur', 'Banda', 'Barabanki', 'Bareilly', 'Basti', 'Bhadohi', 'Bijnor', 'Budaun', 'Bulandshahr', 'Chandauli', 'Chitrakoot', 'Deoria', 'Etah', 'Etawah', 'Farrukhabad', 'Fatehpur', 'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur', 'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi', 'Kannauj', 'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi', 'Kushinagar', 'Lakhimpur Kheri', 'Lalitpur', 'Lucknow', 'Maharajganj', 'Mahoba', 'Mainpuri', 'Mathura', 'Mau', 'Meerut', 'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh', 'Prayagraj', 'Raebareli', 'Rampur', 'Saharanpur', 'Sambhal', 'Sant Kabir Nagar', 'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar', 'Sitapur', 'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi'],
    'West Bengal': ['Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur', 'Darjeeling', 'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram', 'Kalimpong', 'Kolkata', 'Malda', 'Murshidabad', 'Nadia', 'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur', 'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'],
    'Delhi': ['Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi', 'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi', 'West Delhi'],
    'Gujarat': ['Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha', 'Bharuch', 'Bhavnagar', 'Botad', 'Chhota Udaipur', 'Dahod', 'Dang', 'Devbhoomi Dwarka', 'Gandhinagar', 'Gir Somnath', 'Jamnagar', 'Junagadh', 'Kheda', 'Kutch', 'Mahisagar', 'Mehsana', 'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan', 'Porbandar', 'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar', 'Tapi', 'Vadodara', 'Valsad'],
    'Rajasthan': ['Ajmer', 'Alwar', 'Banswara', 'Baran', 'Barmer', 'Bharatpur', 'Bhilwara', 'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa', 'Dholpur', 'Dungarpur', 'Hanumangarh', 'Jaipur', 'Jaisalmer', 'Jalore', 'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Karauli', 'Kota', 'Nagaur', 'Pali', 'Pratapgarh', 'Rajsamand', 'Sawai Madhopur', 'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'],
    'Madhya Pradesh': ['Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat', 'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur', 'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia', 'Dewas', 'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda', 'Hoshangabad', 'Indore', 'Jabalpur', 'Jhabua', 'Katni', 'Khandwa', 'Khargone', 'Maihar', 'Mandla', 'Mandsaur', 'Morena', 'Narsinghpur', 'Neemuch', 'Niwari', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam', 'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni', 'Shahdol', 'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi', 'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'],
    'Kerala': ['Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod', 'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad', 'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'],
    'Telangana': ['Adilabad', 'Bhadradri Kothagudem', 'Hyderabad', 'Jagtial', 'Jangaon', 'Jayashankar', 'Jogulamba', 'Kamareddy', 'Karimnagar', 'Khammam', 'Komaram Bheem', 'Mahabubabad', 'Mahbubnagar', 'Mancherial', 'Medak', 'Medchal', 'Mulugu', 'Nagarkurnool', 'Nalgonda', 'Narayanpet', 'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla', 'Ranga Reddy', 'Sangareddy', 'Siddipet', 'Suryapet', 'Vikarabad', 'Wanaparthy', 'Warangal Rural', 'Warangal Urban', 'Yadadri Bhuvanagiri'],
    'Goa': ['North Goa', 'South Goa'],
    'Punjab': ['Select District'],
    'Haryana': ['Select District'],
    'Himachal Pradesh': ['Select District'],
    'Jharkhand': ['Select District'],
    'Assam': ['Select District'],
    'Bihar': ['Select District'],
    'Chhattisgarh': ['Select District'],
    'Manipur': ['Select District'],
    'Meghalaya': ['Select District'],
    'Mizoram': ['Select District'],
    'Nagaland': ['Select District'],
    'Odisha': ['Select District'],
    'Sikkim': ['East Sikkim', 'North Sikkim', 'South Sikkim', 'West Sikkim'],
    'Tripura': ['Select District'],
    'Uttarakhand': ['Select District'],
    'Puducherry': ['Karaikal', 'Mahe', 'Puducherry', 'Yanam'],
    'Andhra Pradesh': ['Select District'],
    'Arunachal Pradesh': ['Select District'],
  };

  @override
  void initState() {
    super.initState();
    if (widget.supplierData != null) {
      _nameController.text = widget.supplierData!['name'] ?? '';
      _gstinController.text = widget.supplierData!['gstin'] ?? '';
      _panController.text = widget.supplierData!['pan'] ?? '';
      _addressController.text = widget.supplierData!['address'] ?? '';
      _cityController.text = widget.supplierData!['city'] ?? '';
      _pincodeController.text = widget.supplierData!['pincode'] ?? '';
      _phoneController.text = widget.supplierData!['phone'] ?? '';
      _emailController.text = widget.supplierData!['email'] ?? '';
      _selectedState = widget.supplierData!['state'] ?? 'Karnataka';
      _selectedDistrict = widget.supplierData!['district'];  // ✅ LOAD
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? _getUserDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  String? _validateGSTIN(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    
    final gstin = value.trim().toUpperCase();
    if (gstin.length != 15) return 'GSTIN must be 15 characters';
    
    final gstinRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstinRegex.hasMatch(gstin)) return 'Invalid GSTIN format';
    
    return null;
  }

  String? _validatePAN(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    
    final pan = value.trim().toUpperCase();
    if (pan.length != 10) return 'PAN must be 10 characters';
    
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(pan)) return 'Invalid PAN format';
    
    return null;
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    final userRef = _getUserDocRef();
    if (userRef == null) return;

    setState(() => _isSaving = true);

    try {
      final supplierData = {
        'name': _nameController.text.trim(),
        'gstin': _gstinController.text.trim().toUpperCase(),
        'pan': _panController.text.trim().toUpperCase(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _selectedState,
        'stateCode': _indianStates[_selectedState],
        'district': _selectedDistrict,  // ✅ SAVE DISTRICT
        'pincode': _pincodeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'updatedAt': Timestamp.now(),
      };

      if (widget.supplierId == null) {
        supplierData['createdAt'] = Timestamp.now();
        final docRef = await userRef.collection('suppliers').add(supplierData);
        supplierData['id'] = docRef.id;
      } else {
        await userRef.collection('suppliers').doc(widget.supplierId).update(supplierData);
        supplierData['id'] = widget.supplierId;
      }

      if (!mounted) return;
      
      Navigator.pop(context, supplierData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.supplierId == null 
              ? 'Supplier added successfully' 
              : 'Supplier updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplierId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Supplier' : 'Add Supplier'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveSupplier,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Supplier Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) 
                  ? 'Supplier name is required' 
                  : null,
            ),
            const SizedBox(height: 16),

            const Text(
              'GST & Tax Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // NEW:
            GSTINInputField(
              controller: _gstinController,
              label: 'GSTIN (Optional)',
              hint: '22AAAAA0000A1Z5',
              required: false,
              showLiveValidation: true,
              onValidated: (result) {
                // ✅ Auto-fill state when GSTIN is valid
                if (result.isValid) {
                  setState(() {
                    if (result.stateName != null) {
                      _selectedState = result.stateName!;
                      _selectedDistrict = null; // Reset district
                    }
                  });
                  
                  // Show PAN info
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Valid GSTIN - ${result.stateName} | PAN: ${result.pan}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _panController,
              decoration: const InputDecoration(
                labelText: 'PAN (Optional)',
                hintText: 'AAAAA0000A',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              ],
              textCapitalization: TextCapitalization.characters,
              validator: _validatePAN,
            ),
            const SizedBox(height: 16),

            const Text(
              'Address Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) 
                  ? 'Address is required' 
                  : null,
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) 
                        ? 'Required' 
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _pincodeController,
                    decoration: const InputDecoration(
                      labelText: 'Pincode *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(6),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) => (v == null || v.trim().length != 6) 
                        ? 'Invalid' 
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // ✅ STATE DROPDOWN
            DropdownButtonFormField<String>(
              initialValue: _selectedState,
              decoration: const InputDecoration(
                labelText: 'State *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
                helperText: 'Required for GST calculation',
              ),
              items: _indianStates.keys.map((state) {
                return DropdownMenuItem(
                  value: state,
                  child: Text('$state (${_indianStates[state]})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedState = value;
                    _selectedDistrict = null;  // ✅ RESET
                  });
                }
              },
              validator: (v) => (v == null || v.isEmpty) ? 'State required' : null,
            ),
            const SizedBox(height: 12),

            // ✅ DISTRICT DROPDOWN (NEW!)
            DropdownButtonFormField<String>(
              initialValue: _selectedDistrict,
              decoration: InputDecoration(
                labelText: 'District *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_city),
                helperText: 'Select state first',
                enabled: _stateDistricts[_selectedState]?.isNotEmpty == true,
              ),
              items: (_stateDistricts[_selectedState] ?? []).map((district) {
                return DropdownMenuItem(
                  value: district,
                  child: Text(district),
                );
              }).toList(),
              onChanged: (_stateDistricts[_selectedState]?.isNotEmpty == true)
                  ? (value) {
                      setState(() => _selectedDistrict = value);
                    }
                  : null,
              validator: (v) {
                if (_stateDistricts[_selectedState]?.contains('Select District') == true) {
                  return null; // Optional for states without data
                }
                return (v == null || v.isEmpty) ? 'District required' : null;
              },
            ),

            const SizedBox(height: 16),

            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Invalid email format';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
